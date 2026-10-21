-- The window manager's logic: the wallpaper, and what the shell is told about
-- workspaces, the focused monitor and the overview. The shell answers to
-- `pleamar-wm --say desk`; when it is not running the calls simply fail.

-- The window manager itself has no PLEAMAR_SOCKETS, where the scenes of its
-- session (the shell) keep theirs: it is named after its first display.
local function tell(...)
    run("sh", { "-c", 'PLEAMAR_SOCKETS="$XDG_RUNTIME_DIR/pleamar-pleamar-1" exec pleamar-wm --say desk "$@"', "sh", ... }, nil, { output = false })
end

-- the shell
on("ws_report", function(code)
    local s = code % 4
    code = (code - s) / 4
    local shown = code % 16
    code = (code - shown) / 16
    local pools = code % 16
    local occ = (code - pools) / 16
    tell(
        "fact ws.shown." .. s .. " " .. shown,
        "fact ws.pools." .. s .. " " .. pools,
        "fact ws.occ." .. s .. " " .. occ
    )
end)
on("focus_report", function(s) tell("fact focmon " .. s) end)
on("width_report", function(code)
    local s = code % 4
    tell("fact mw." .. s .. " " .. (code - s) / 4)
end)
on("height_report", function(code)
    local s = code % 4
    tell("fact mh." .. s .. " " .. (code - s) / 4)
end)
on("ptr_report", function(code)
    tell("fact ptrmon " .. code % 4, "fact dragging " .. tostring(code >= 4))
end)
-- each monitor's overview: s + 4 while open
on("ov_report", function(code)
    local s = code % 4
    tell("fact ovm." .. s .. " " .. tostring(code >= 4))
end)
-- ...and what it is as this starts: a scene read again has its overviews
-- closed with no change to report, and the shell, left with an open one,
-- would only ever close it.
do
    local ovs = {}
    for s = 0, 3 do
        table.insert(ovs, "fact ovm." .. s .. " " .. tostring(fact["ov." .. s] == true))
    end
    tell(table.unpack(ovs))
end

-- the wallpaper: two slots, the new one fading in over the old. The new one is
-- put in the hidden slot first and faded to a moment later, once it has been
-- read, or the fade goes towards a slot that is still empty and flashes dark.
-- Read back from the scene, which keeps it across a reload of this file.
local pick = fact["wall.pick"] or 0
local busy = false
local function show(path)
    -- the last line: the path, after anything a tool printed on the way
    path = (path or ""):match("([^\n]*)%s*$") or ""
    if path == "" or path == text[pick == 0 and "wall.a" or "wall.b"] then
        busy = false
        fact["wall.busy"] = false
        return
    end
    if pick == 0 then text["wall.b"] = path else text["wall.a"] = path end
    after(400, function()
        pick = 1 - pick
        fact["wall.pick"] = pick
        busy = false
        fact["wall.busy"] = false
    end)
end

local function wallpaper(args)
    if busy then return end
    busy = true
    fact["wall.busy"] = true
    run("pleamar-wallpaper", args, function(out, code)
        if code == 0 then
            show(out)
        else
            busy = false
            fact["wall.busy"] = false
        end
    end)
end

-- The first one is there at once; the rest fade in.
run("pleamar-wallpaper", { "current" }, function(out, code)
    if code ~= 0 then return end
    out = out:match("([^\n]*)%s*$") or ""
    text["wall.a"] = out
    text["wall.b"] = out
end)
on("wall_next", function() wallpaper({ "next" }) end)
on("wall_set", function() wallpaper({ "set", text["wall.req"] }) end)

-- the task bar: every window, by monitor, then workspace, then row top to
-- bottom and left to right within the row. Sent as rows of fields, with
-- the ASCII record and unit separators between them.
local function on_(v) return v == true or (type(v) == "number" and v > 0.5) end
local tbPending, tbLast = false, nil
local function tbSend()
    tbPending = false
    local rows = {}
    for i = 0, 15 do
        local w = "win." .. i .. "."
        local sc = fact[w .. "screen"] or 0
        if on_(fact[w .. "open"]) and not on_(fact[w .. "dialog"]) then
            rows[#rows + 1] = {
                i = i,
                sc = sc,
                ws = fact[w .. "workspace"] or 0,
                c = fact["cpos." .. i] or 0,
                r = fact["rpos." .. i] or 0,
            }
        end
    end
    table.sort(rows, function(a, b)
        if a.sc ~= b.sc then return a.sc < b.sc end
        if a.ws ~= b.ws then return a.ws < b.ws end
        if a.r ~= b.r then return a.r < b.r end
        if a.c ~= b.c then return a.c < b.c end
        return a.i < b.i
    end)
    local out = {}
    for _, r in ipairs(rows) do
        local w = "win." .. r.i .. "."
        out[#out + 1] = table.concat({
            r.i,
            on_(fact[w .. "focused"]) and 1 or 0,
            on_(fact[w .. "urgent"]) and 1 or 0,
            r.sc,
            text[w .. "app"] or "",
            text[w .. "title"] or "",
        }, "\31")
    end
    local payload = table.concat(out, "\30")
    if payload == tbLast then return end
    tbLast = payload
    tell("text tb.data " .. payload, "emit tb_data")
end
on("tb_dirty", function()
    if tbPending then return end
    tbPending = true
    after(50, tbSend)
end)
-- Titles change without a fact to say so: looked at now and then.
every(2000, tbSend)
on("tb_hello", function()
    tbLast = nil
    tbSend()
end)

-- The agent cursor's clock (agc.clock, ms), for its frames: only while an
-- agent's cursor shows. A `spin` in this scene runs once per monitor drawing
-- it, so the time is kept here.
local AGC_STEP = 30
every(AGC_STEP, function()
    if fact["ag.recent"] or on_(fact["agent.active"]) then
        fact["agc.clock"] = (fact["agc.clock"] or 0) + AGC_STEP
    end
end)
