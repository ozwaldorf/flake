-- The window manager's logic: the wallpaper, and what the shell is told about
-- workspaces, the focused monitor and the overview. The shell answers to
-- `pleamar-wm --say desk`; when it is not running the calls simply fail.

-- The window manager itself has no PLEAMAR_SOCKETS, where the scenes of its
-- session (the shell) keep theirs: it is named after its first display.
-- A screenless one (pleamar-wm headless, a test) has PLEAMAR_SOCKETS and its
-- shell lives where wm.sock leads back to it: told there or nowhere, never the
-- real session's shell.
local SAY = [[
d="$XDG_RUNTIME_DIR/pleamar-pleamar-1"
if [ -n "$PLEAMAR_SOCKETS" ]; then
    d=
    for x in "$XDG_RUNTIME_DIR"/pleamar-pleamar-*; do
        [ "$(readlink "$x/wm.sock")" = "$PLEAMAR_SOCKETS/session.sock" ] && d="$x"
    done
    [ -n "$d" ] || exit 0
fi
PLEAMAR_SOCKETS="$d" exec pleamar-wm --say desk "$@"
]]

-- One message at a time, in order: each is a process of its own, and two let
-- go together raced, the older one sometimes landing last (an overview the
-- shell kept open). What comes in meanwhile goes in the next one.
local queue, busy = {}, false
local function pump()
    if busy or #queue == 0 then
        return
    end
    busy = true
    local cmds = queue
    queue = {}
    run("sh", { "-c", SAY, "sh", table.unpack(cmds) }, function()
        busy = false
        pump()
    end, { output = false })
end
local function tell(...)
    for _, c in ipairs({ ... }) do
        table.insert(queue, c)
    end
    pump()
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

local function on_(v) return v == true or (type(v) == "number" and v > 0.5) end

-- The agent cursor's clock (agc.clock, ms), for its frames: only while an
-- agent's cursor shows. A `spin` in this scene runs once per monitor drawing
-- it, so the time is kept here.
local AGC_STEP = 30
every(AGC_STEP, function()
    if fact["ag.recent"] or on_(fact["agent.active"]) then
        fact["agc.clock"] = (fact["agc.clock"] or 0) + AGC_STEP
    end
end)
