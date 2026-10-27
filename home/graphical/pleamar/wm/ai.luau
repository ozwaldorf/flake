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

-- What was written while it worked, sent when the turn ends (below).
local flush
local function set_state(c, s, words)
    fact["sb.state." .. c.k] = s
    text["sb.status." .. c.k] = words or ""
    if s == "idle" and c.queue and #c.queue > 0 then
        after(10, function() if ch[c.k] == c then flush(c) end end)
    end
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

-- Which program each conversation was about (provider, its session or
-- thread id, app), a line each, for the list of conversations and /resume.
local STATE = '"${XDG_STATE_HOME:-$HOME/.local/state}/pleamar-wm"'
local function record(c, id)
    run("sh", { "-c", "mkdir -p " .. STATE .. ' && printf "%s\\t%s\\t%s\\n" "$1" "$2" "$3" >> ' .. STATE .. "/ai-sessions", "sh", tostring(c.prov), id, c.app }, function() end)
end

-- What the user said, without what went with it: the window's tree before
-- the first message, and Codex's instructions before that.
local function said(t)
    t = tostring(t or "")
    if t:sub(1, 33) == "You are an assistant in a sidebar" then t = t:match("^.-\n\n(.*)$") or t end
    return t:match("^The window as it is now %(`tree.-\n```\n\n(.*)$") or t
end

-- ── Claude Code ──

local function claude_event(c, m)
    local p = c.claude
    if m.type == "system" and m.subtype == "init" and m.session_id and m.session_id ~= p.session then
        p.session = m.session_id
        record(c, p.session)
    elseif m.type == "stream_event" and type(m.event) == "table" then
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
    if p.session then
        table.insert(args, "--resume")
        table.insert(args, p.session)
    end
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
        c.queue, c.waiting = {}, {}
    end,
}

-- ── Codex ──

local function codex_event(c, m)
    local p = c.codex
    if m.type == "thread.started" then
        p.thread = m.thread_id
        record(c, p.thread)
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
        c.queue, c.waiting = {}, {}
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
        queue = {},
        waiting = {},
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

-- A conversation's rows from its file: Claude Code's session, or Codex's
-- rollout of that thread.
local function history(c, out)
    c.rows = {}
    for line in tostring(out or ""):gmatch("[^\n]+") do
        local good, m = pcall(json.decode, line)
        if not good or type(m) ~= "table" then continue end
        local msg, role = m.message, m.type
        if role == "response_item" and type(m.payload) == "table" then
            msg, role = m.payload, m.payload.role
            if m.payload.type == "function_call" then
                local ok, a = pcall(json.decode, m.payload.arguments or "")
                tool_row(c, m.payload.name, ok and a or nil).state = 1
            end
        end
        if m.isMeta or type(msg) ~= "table" then continue end
        local content = msg.content
        if type(content) == "string" then content = { { type = "text", text = content } } end
        if type(content) ~= "table" then continue end
        for _, b in ipairs(content) do
            local words = (b.type == "text" or b.type == "input_text" or b.type == "output_text") and tostring(b.text or "")
            if words and role == "user" and not words:match("^%s*<") then
                add(c, 1, said(words))
            elseif words and role == "assistant" and words ~= "" then
                add(c, 2, words)
            elseif b.type == "tool_use" and role == "assistant" then
                tool_row(c, b.name, b.input).state = 1
            end
        end
    end
    paint(c)
end

-- The provider's sidebar conversations, newest first, about this window's
-- program: each its id, when, and the first thing said in it. The program is
-- the one recorded; for one from before that was, Codex's first message
-- names it, and Claude Code's names the window's process, which is matched
-- while that still runs.
local SHOWN = 8
local MARK = {
    [0] = [["text":"The window as it is now (`tree]],
    [1] = [["text":"You are an assistant in a sidebar]],
}
local LIST = {
    [0] = [[grep -lF "$1" "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | xargs -r ls -t | head -n 60 | while read -r f; do printf 'S\t%s\t%s\t' "$(basename "$f" .jsonl)" "$(stat -c %Y "$f")"; grep -m 1 -F "$1" "$f"; done]],
    [1] = [[grep -rlF "$1" "$HOME/.codex/sessions" 2>/dev/null | xargs -r ls -t | head -n 60 | while read -r f; do printf 'S\t%s\t%s\t' "$(basename "$f" .jsonl | grep -o '[0-9a-f-]\{36\}$')" "$(stat -c %Y "$f")"; grep -m 1 -F "$1" "$f"; done]],
}
local AROUND = [[printf 'N\t%s\n' "$(date +%s)"; sed 's/^/I\t/' ]] .. STATE .. [[/ai-sessions 2>/dev/null; pleamar-wm agent windows 2>/dev/null | awk '{ print "W\t" $1 "\t" $2 }'; ]]
local function ago(s)
    if s < 3600 then return math.max(1, s // 60) .. "m" end
    if s < 86400 then return s // 3600 .. "h" end
    return s // 86400 .. "d"
end
local function first_text(m)
    local msg = type(m.payload) == "table" and m.payload or m.message
    local content = type(msg) == "table" and msg.content
    if type(content) == "string" then return content end
    for _, b in ipairs(type(content) == "table" and content or {}) do
        if type(b.text) == "string" then return b.text end
    end
    return ""
end
local function list(c, done)
    run("sh", { "-c", AROUND .. LIST[c.prov], "sh", MARK[c.prov] }, function(out)
        if ch[c.k] ~= c then return end
        local now, apps, procs = 0, {}, {}
        local current = c.prov == 1 and c.codex.thread or c.claude.session
        c.sessions = {}
        fact["sb.scur." .. c.k] = -1
        for line in tostring(out or ""):gmatch("[^\n]+") do
            local kind, rest = line:match("^(%u)\t(.*)$")
            if kind == "N" then
                now = tonumber(rest) or 0
            elseif kind == "I" then
                local prov, id, app = rest:match("^(%d)\t([%w%-]+)\t(.*)$")
                if tonumber(prov) == c.prov then apps[id] = app end
            elseif kind == "W" then
                local pid, app = rest:match("^(%S+)\t(%S+)$")
                if pid then procs[pid] = app end
            elseif kind == "S" and #c.sessions < SHOWN then
                local id, t, js = rest:match("^([%w%-]+)\t(%d+)\t(.*)$")
                local good, m = pcall(json.decode, js or "")
                local words = (good and type(m) == "table") and first_text(m) or ""
                local app = id and (apps[id] or words:match("^You are an assistant.-window %S+ %(([^,]+), titled") or procs[words:match("`tree (%d+)`") or ""])
                if app == c.app then
                    local j = #c.sessions
                    table.insert(c.sessions, id)
                    text["sbs." .. c.k .. "." .. j .. ".title"] = said(words):match("^%s*([^\n]*)") or id
                    text["sbs." .. c.k .. "." .. j .. ".when"] = ago(math.max(0, now - tonumber(t)))
                    if id == current then fact["sb.scur." .. c.k] = j end
                end
            end
        end
        fact["sb.sn." .. c.k] = #c.sessions
        if done then done() end
    end)
end

-- /resume [id]: back to that conversation, or the last one about this
-- program, its thread shown again.
local FILES = {
    [0] = 'cat "$HOME"/.claude/projects/*/"$1".jsonl 2>/dev/null',
    [1] = 'f=$(find "$HOME/.codex/sessions" -name "*$1.jsonl" 2>/dev/null | head -n 1); [ -n "$f" ] && cat "$f"',
}
local function resume(c, id)
    if not id then
        return list(c, function()
            local current = c.prov == 1 and c.codex.thread or c.claude.session
            local last = c.sessions[1] == current and c.sessions[2] or c.sessions[1]
            if last then return resume(c, last) end
            add(c, 4, "Nothing to resume for " .. c.app)
        end)
    end
    c.p.reset(c)
    c.primed = false
    if c.prov == 1 then c.codex.thread = id else c.claude.session = id end
    set_state(c, "starting", "Resuming")
    run("sh", { "-c", FILES[c.prov], "sh", id }, function(out)
        if ch[c.k] ~= c then return end
        history(c, out)
        if #c.rows == 0 then add(c, 4, "No conversation " .. id .. " found: it starts from there anyway") end
        set_state(c, "idle", "Resumed " .. id:sub(1, 8))
        if c.prov == 0 then claude_start(c) end
    end)
end

local deliver

on("sb_list", function(k)
    local c = ch[math.floor(k or 0)]
    if c then list(c) end
end)

on("sb_pick", function(v)
    v = math.floor(v or 0)
    local c = ch[v // SHOWN]
    local id = c and c.sessions and c.sessions[v % SHOWN + 1]
    if id then resume(c, id) end
end)

on("sb_send", function(k)
    local c = ch[math.floor(k or 0)]
    if not c or c.pid == "" then return end
    local s = fact["sb.state." .. c.k]
    local field = "sbin." .. (fact["sb.win." .. c.k] or 0)
    local words = (text[field] or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local now = held("Control_L") or held("Control_R")
    local busy = s == "working" or s == "starting"
    -- While it works, what is written waits for the turn to end; Ctrl+Enter
    -- ends the turn so it goes now (an empty one, what is already waiting).
    if busy then
        if words ~= "" then
            text[field] = ""
            table.insert(c.queue, words)
            table.insert(c.waiting, add(c, 1, words, "", 1))
        end
        if now and #c.queue > 0 and s == "working" then c.p.stop(c) end
        return
    end
    if words == "" then return end
    text[field] = ""
    local cmd, arg = words:match("^/(%a+)%s*([%w%-]*)$")
    if cmd == "resume" then return resume(c, arg ~= "" and arg or nil) end
    add(c, 1, words)
    deliver(c, words)
end)

-- Sent: to the provider, the first of a conversation with the window as it is.
deliver = function(c, words)
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
end

flush = function(c)
    local words = table.concat(c.queue, "\n\n")
    c.queue = {}
    -- under what was answered while they waited
    for _, r in ipairs(c.waiting) do
        local at = table.find(c.rows, r)
        if at then table.remove(c.rows, at) end
        r.state = 0
        table.insert(c.rows, r)
    end
    c.waiting = {}
    paint(c)
    deliver(c, words)
end

on("sb_stop", function(k)
    local c = ch[math.floor(k or 0)]
    if not c then return end
    -- what waited goes with it
    for _, r in ipairs(c.waiting) do table.remove(c.rows, table.find(c.rows, r) or #c.rows + 1) end
    c.queue, c.waiting = {}, {}
    c.p.stop(c)
    add(c, 4, "Stopped")
    run("pleamar-wm", { "agent", "done" }, function() end)
end)

-- A row's copy button: channel * MAX + row.
on("sb_copy", function(v)
    v = math.floor(v or 0)
    local words = text["sbr." .. (v // MAX) .. "." .. (v % MAX) .. ".text"] or ""
    if words == "" then return end
    run("wl-copy", {}, nil, { input = words, output = false })
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
