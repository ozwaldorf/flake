-- The AI sidebar's logic (ai.plm): one provider's CLI per channel, headless,
-- painted into that channel's thread.
--
-- Claude Code runs once per conversation in stream-json mode, its input left
-- open for each message. Codex runs once per turn (`codex exec --json`), each
-- turn after the first resuming its thread. Both get pleamar-wm's agent hands
-- as the pleamar-desktop MCP server, and are told which window is theirs.

local CLAUDE = { "run", "github:sadjow/claude-code-nix", "--" }
local CODEX = { "run", "github:sadjow/codex-cli-nix", "--" }
local MCP = '{"mcpServers":{"pleamar-desktop":{"command":"pleamar-wm","args":["agent","mcp"]}}}'
local MAX = 32
local CHANNELS = 4
-- How much of the window goes with a conversation's first message (a
-- terminal's tree takes no --max: its lines are its screen).
local TREE_CHARS = 12000

local function scope(c)
    return table.concat({
        "You are an assistant in a sidebar attached to one window on the user's pleamar-wm desktop:",
        string.format("window %s (%s, titled «%s»).", c.pid, c.app, c.title),
        "Questions are about that window unless the user says otherwise.",
        "You reach it with the pleamar-desktop tools: always pass window " .. c.pid .. " (or " .. c.pid .. ".N for its own dialogs).",
        "The first message of a conversation comes with the window's tree as it was just before it; read again (tree --since) after acting, and look only when reading cannot tell.",
        "Do not touch other windows unless the user asks. Call done when you finish acting.",
        "The sidebar is narrow: answer briefly, in short paragraphs.",
    }, " ")
end

local ch = {}

-- The thread goes to the scene row by row (sbr.K.N.*), each field only when
-- it changed since it was last written.
local EMPTY = { kind = 0, text = "", detail = "", state = 0 }
local function paint(c)
    while #c.rows > MAX do table.remove(c.rows, 1) end
    for n = 1, MAX do
        local r = c.rows[n] or EMPTY
        local s = c.shown[n] or {}
        local base = "sbr." .. c.k .. "." .. (n - 1) .. "."
        if s.kind ~= r.kind then fact[base .. "kind"] = r.kind end
        if s.state ~= r.state then fact[base .. "state"] = r.state end
        if s.text ~= r.text then text[base .. "text"] = r.text end
        if s.detail ~= r.detail then text[base .. "detail"] = r.detail end
        c.shown[n] = { kind = r.kind, text = r.text, detail = r.detail, state = r.state }
    end
    fact["sb.n." .. c.k] = #c.rows
end

local function add(c, kind, words, detail, state)
    local r = { kind = kind, text = words or "", detail = detail or "", state = state or 0 }
    table.insert(c.rows, r)
    paint(c)
    return r
end

local function set_state(c, s, words)
    fact["sb.state." .. c.k] = s
    text["sb.status." .. c.k] = words or ""
end

-- A tool, as the thread shows it: its name, and what it was pointed at.
local function tool_row(c, name, args)
    local short = tostring(name):gsub("^mcp__pleamar%-desktop__", "")
    local detail = ""
    if type(args) == "table" then
        detail = args.element or args.text or args.command or args.key or args.words or ""
        if type(detail) ~= "string" then detail = tostring(detail) end
    end
    return add(c, 3, short, (detail:gsub("%s+", " ")), 0)
end

-- ── Claude Code ──

local function claude_event(c, m)
    local p = c.claude
    if m.type == "stream_event" and type(m.event) == "table" then
        local e = m.event
        if e.type == "content_block_start" and e.content_block and e.content_block.type == "text" then
            p.live = add(c, 2, "")
        elseif e.type == "content_block_delta" and e.delta and e.delta.type == "text_delta" and p.live then
            p.live.text = p.live.text .. tostring(e.delta.text or "")
            paint(c)
        elseif e.type == "content_block_stop" then
            p.live = nil
        end
    elseif m.type == "assistant" and m.message and type(m.message.content) == "table" then
        for _, b in ipairs(m.message.content) do
            if b.type == "tool_use" and b.id and not p.tools[b.id] then
                p.tools[b.id] = tool_row(c, b.name, b.input)
                set_state(c, "working", "Using " .. p.tools[b.id].text)
            end
        end
    elseif m.type == "user" and m.message and type(m.message.content) == "table" then
        for _, b in ipairs(m.message.content) do
            local r = b.type == "tool_result" and p.tools[b.tool_use_id]
            if r then
                r.state = b.is_error and 2 or 1
                paint(c)
            end
        end
        set_state(c, "working", "Thinking")
    elseif m.type == "result" then
        if m.is_error and not p.stopping then add(c, 4, tostring(m.result or m.subtype)) end
        p.stopping = false
        p.live = nil
        set_state(c, "idle", "")
    end
end

local function claude_start(c)
    if c.claude.id then return end
    local args = table.clone(CLAUDE)
    for _, a in ipairs({
        "-p", "--input-format", "stream-json", "--output-format", "stream-json",
        "--verbose", "--include-partial-messages",
        "--mcp-config", MCP, "--strict-mcp-config",
        "--allowedTools", "mcp__pleamar-desktop", "WebSearch", "WebFetch",
        "--append-system-prompt", scope(c),
    }) do table.insert(args, a) end
    local p = c.claude
    local ok, id = pcall(spawn, "nix", args, function(line)
        if line:sub(1, 1) ~= "{" then return end
        local good, m = pcall(json.decode, line)
        if good and type(m) == "table" and ch[c.k] == c then claude_event(c, m) end
    end, function(_, code)
        p.id = nil
        if ch[c.k] == c and fact["sb.state." .. c.k] ~= "idle" then
            add(c, 4, "Claude Code ended (" .. tostring(code) .. ")")
            set_state(c, "idle", "")
        end
    end, { stdin = "open" })
    if not ok then
        set_state(c, "offline", "Cannot start Claude Code: " .. tostring(id))
        return
    end
    p.id = id
end

local claude = {
    send = function(c, words)
        claude_start(c)
        if not c.claude.id then return end
        write(c.claude.id, json.encode({
            type = "user",
            message = { role = "user", content = { { type = "text", text = words } } },
        }) .. "\n")
        set_state(c, "working", "Thinking")
    end,
    stop = function(c)
        if not c.claude.id then return end
        c.claude.stopping = true
        write(c.claude.id, json.encode({ type = "control_request", request_id = "stop", request = { subtype = "interrupt" } }) .. "\n")
    end,
    reset = function(c)
        if c.claude.id then kill(c.claude.id) end
        c.claude = { tools = {} }
    end,
}

-- ── Codex ──

local function codex_event(c, m)
    local p = c.codex
    if m.type == "thread.started" then
        p.thread = m.thread_id
        return
    end
    local it = m.item
    if type(it) ~= "table" then
        if m.type == "turn.failed" or m.type == "error" then
            add(c, 4, tostring((m.error and m.error.message) or m.message or "Codex failed"))
        end
        return
    end
    if it.type == "agent_message" and m.type == "item.completed" then
        add(c, 2, tostring(it.text or ""))
    elseif it.type == "mcp_tool_call" or it.type == "command_execution" then
        local r = p.tools[it.id]
        if not r then
            r = tool_row(c, it.type == "mcp_tool_call" and it.tool or "shell", it.arguments or { command = it.command })
            p.tools[it.id] = r
            set_state(c, "working", "Using " .. r.text)
        end
        if m.type == "item.completed" then
            r.state = (it.status == "failed" or it.error) and 2 or 1
            paint(c)
            set_state(c, "working", "Thinking")
        end
    end
end

local codex = {
    send = function(c, words)
        local p = c.codex
        if p.id then return end
        local args = table.clone(CODEX)
        for _, a in ipairs({
            "exec", "--json", "--skip-git-repo-check", "-s", "read-only",
            "-c", 'mcp_servers.pleamar-desktop.command="pleamar-wm"',
            "-c", 'mcp_servers.pleamar-desktop.args=["agent","mcp"]',
            "-c", 'mcp_servers.pleamar-desktop.default_tools_approval_mode="approve"',
            "-c", 'mcp_servers.pleamar-desktop.env_vars=["XDG_RUNTIME_DIR","WAYLAND_DISPLAY","PLEAMAR_SOCKETS"]',
        }) do table.insert(args, a) end
        -- Codex exec has no system prompt of its own: the first turn carries it.
        local prompt = words
        if p.thread then
            table.insert(args, "resume")
            table.insert(args, p.thread)
        else
            prompt = scope(c) .. "\n\n" .. words
        end
        table.insert(args, "-")
        set_state(c, "starting", "Starting Codex")
        local ok, id = pcall(spawn, "nix", args, function(line)
            if line:sub(1, 1) ~= "{" or ch[c.k] ~= c then return end
            local good, m = pcall(json.decode, line)
            if good and type(m) == "table" then
                if fact["sb.state." .. c.k] == "starting" then set_state(c, "working", "Thinking") end
                codex_event(c, m)
            end
        end, function(_, code)
            p.id = nil
            if ch[c.k] ~= c then return end
            if code ~= 0 and fact["sb.state." .. c.k] ~= "idle" then add(c, 4, "Codex ended (" .. tostring(code) .. ")") end
            set_state(c, "idle", "")
        end, { input = prompt })
        if not ok then
            set_state(c, "offline", "Cannot start Codex: " .. tostring(id))
            return
        end
        p.id = id
    end,
    stop = function(c)
        if c.codex.id then kill(c.codex.id, "int") end
    end,
    reset = function(c)
        if c.codex.id then kill(c.codex.id) end
        c.codex = { tools = {} }
    end,
}

-- ── the channels ──

local function paint_target(c)
    text["sb.target." .. c.k] = c.pid ~= "" and string.format("%s · %s", c.app, c.title) or "Finding the window..."
end

-- The window's PID, by its title and program among the windows the agent
-- sees; of several alike, the one with the keyboard.
-- (A title is compared without what leads it before a letter: a spinner.)
local function bare(t) return (tostring(t or ""):gsub("^[^%w]+", "")) end
local function find_window(c)
    run("pleamar-wm", { "agent", "windows" }, function(out)
        if ch[c.k] ~= c then return end
        local best
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local p, a, t = line:match("^%s*(%S+)%s+(%S+)%s+«(.-)»")
            if p and bare(t) == bare(c.title) and (c.app == "" or a == c.app) then
                if not best or line:find("has the keyboard", 1, true) then best = { p, a } end
            end
        end
        if best then
            c.pid, c.app = best[1], best[2]
            paint_target(c)
            set_state(c, "idle", "")
            if c.prov == 0 then claude_start(c) end
        else
            set_state(c, "offline", "Cannot find this window among the agent's")
        end
    end)
end

local function open(k, app, title)
    if ch[k] then ch[k].p.reset(ch[k]) end
    local prov = fact["sb.prov." .. k] or 0
    local c = {
        k = k,
        prov = prov,
        p = prov == 1 and codex or claude,
        pid = "",
        app = app,
        title = title,
        rows = {},
        -- what the scene holds of each row: unknown, so all of it is written
        shown = {},
        claude = { tools = {} },
        codex = { tools = {} },
    }
    ch[k] = c
    text["sbin." .. (fact["sb.win." .. k] or 0)] = ""
    paint(c)
    paint_target(c)
    set_state(c, "starting", "Finding the window")
    find_window(c)
end

on("sb_start", function(k)
    open(math.floor(k or 0), text["sb.reqapp"] or "", text["sb.req"] or "")
end)

-- Sidebars left open across a reload of this logic: their window again, by
-- the name they show, in a new conversation.
for k = 0, CHANNELS - 1 do
    if (fact["sb.win." .. k] or -1) >= 0 then
        local app, title = (text["sb.target." .. k] or ""):match("^(%S+) · (.*)$")
        if app then open(k, app, title) end
    end
end

on("sb_send", function(k)
    local c = ch[math.floor(k or 0)]
    if not c or c.pid == "" then return end
    local s = fact["sb.state." .. c.k]
    local field = "sbin." .. (fact["sb.win." .. c.k] or 0)
    local words = (text[field] or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if words == "" or s == "working" or s == "starting" then return end
    text[field] = ""
    add(c, 1, words)
    if c.primed then return c.p.send(c, words) end
    -- The first of a conversation goes with the window as it is, read here:
    -- the agent starts from it instead of asking for it.
    c.primed = true
    set_state(c, "working", "Reading the window")
    run("pleamar-wm", { "agent", "tree", c.pid }, function(out, code)
        if ch[c.k] ~= c then return end
        local tree = tostring(out or "")
        if code ~= 0 or tree:match("^%s*$") then return c.p.send(c, words) end
        if #tree > TREE_CHARS then tree = tree:sub(1, TREE_CHARS) .. "\n..." end
        c.p.send(c, string.format("The window as it is now (`tree %s`, read just before this message):\n```\n%s\n```\n\n%s", c.pid, tree, words))
    end)
end)

on("sb_stop", function(k)
    local c = ch[math.floor(k or 0)]
    if not c then return end
    c.p.stop(c)
    add(c, 4, "Stopped")
    run("pleamar-wm", { "agent", "done" }, function() end)
end)

on("sb_new", function(k)
    local c = ch[math.floor(k or 0)]
    if not c then return end
    c.p.reset(c)
    c.primed = false
    c.rows = {}
    paint(c)
    set_state(c, "idle", "")
    if c.prov == 0 then claude_start(c) end
end)

on("sb_close", function(k)
    k = math.floor(k or 0)
    local c = ch[k]
    if not c then return end
    c.p.reset(c)
    c.rows = {}
    paint(c)
    ch[k] = nil
    set_state(c, "idle", "")
end)

-- The spinners' clock, kept here: a rule's timer would run once per monitor.
every(30, function()
    for k = 0, CHANNELS - 1 do
        if fact["sb.state." .. k] == "working" then
            fact["sb.t"] = (fact["sb.t"] or 0) + 0.03
            return
        end
    end
end)

-- Titles kept current.
every(5000, function()
    if next(ch) == nil then return end
    run("pleamar-wm", { "agent", "windows" }, function(out)
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local p, a, t = line:match("^%s*(%S+)%s+(%S+)%s+«(.-)»")
            for _, c in pairs(ch) do
                if p == c.pid and t and t ~= c.title then
                    c.title = t
                    paint_target(c)
                end
            end
        end
    end)
end)

-- A sidebar not yet talked to, switched to the other provider.
on("sb_switch", function(k)
    local c = ch[math.floor(k or 0)]
    if not c then return end
    c.p.reset(c)
    c.prov = fact["sb.prov." .. c.k] or 0
    c.p = c.prov == 1 and codex or claude
    c.primed = false
    set_state(c, "idle", "")
    if c.prov == 0 and c.pid ~= "" then claude_start(c) end
end)

-- The provider chosen last, the next sidebar's: kept across sessions.
local LAST = '"${XDG_STATE_HOME:-$HOME/.local/state}/pleamar-wm/ai-provider"'
run("sh", { "-c", "cat " .. LAST .. " 2>/dev/null" }, function(out)
    if tostring(out or ""):match("codex") then fact["sb.last"] = 1 end
end)
on("fact:sb.last", function(v)
    run("sh", { "-c", 'mkdir -p "$(dirname ' .. LAST .. ')" && printf %s "$1" > ' .. LAST, "sh", v == 1 and "codex" or "claude" }, function() end)
end)
