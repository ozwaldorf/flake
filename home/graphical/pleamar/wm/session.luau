-- The window manager's logic: the wallpaper, and what the shell is told about
-- workspaces, the focused monitor and the overview. The shell answers to
-- `pleamar-wm --say desk`; when it is not running the calls simply fail.

-- The window manager itself has no PLEAMAR_SOCKETS, where the scenes of its
-- session (the shell) keep theirs: it is named after its first display.
-- A screenless one (pleamar-wm headless, a test) has PLEAMAR_SOCKETS and its
-- shell lives where wm.sock leads back to it: told there or nowhere, never the
-- real session's shell.
local SOCKETS = [[
d="$XDG_RUNTIME_DIR/pleamar-pleamar-1"
if [ -n "$PLEAMAR_SOCKETS" ]; then
    d=
    for x in "$XDG_RUNTIME_DIR"/pleamar-pleamar-*; do
        [ "$(readlink "$x/wm.sock")" = "$PLEAMAR_SOCKETS/session.sock" ] && d="$x"
    done
    [ -n "$d" ] || exit 0
fi
]]
local SAY = SOCKETS .. [[PLEAMAR_SOCKETS="$d" exec pleamar-wm --say desk "$@"]]

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
on("phone_report", function(p) tell("fact phone " .. (p - 1)) end)

-- where each monitor sits on the desktop, by its number, as the compositor
-- has it; asked again whenever a monitor or the pointer's changes
local placing = false
local function place()
    if placing then return end
    placing = true
    run("sh", { "-c", SOCKETS .. [[PLEAMAR_SOCKETS="$d" exec pleamar-wm hyprctl monitors]] }, function(out, code)
        placing = false
        if code ~= 0 then return end
        local found = false
        for id, x, y in out:gmatch("%(ID (%d+)%):%s*[^\n]* at (%-?%d+)x(%-?%d+)") do
            if tonumber(id) < 4 then
                fact["mpos.x." .. id] = tonumber(x)
                fact["mpos.y." .. id] = tonumber(y)
                found = true
            end
        end
        fact["mpos.ok"] = found
    end)
end
place()

on("width_report", function(code)
    local s = code % 4
    tell("fact mw." .. s .. " " .. (code - s) / 4)
    place()
end)
on("height_report", function(code)
    local s = code % 4
    tell("fact mh." .. s .. " " .. (code - s) / 4)
    place()
end)
on("ptr_report", function(code)
    tell("fact ptrmon " .. code % 4, "fact dragging " .. tostring(code >= 4))
    place()
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

-- the wallpaper: two slots, the new one put in the hidden slot and faded in
-- over the old. Read back from the scene, which keeps it across a reload of
-- this file. Each picture is graded through the carburetor CLUT the first time
-- it is shown, and the graded copy kept.
local pick = fact["wall.pick"] or 0
local changing = false
local walls, state, cache, clut = "", "", "", ""
-- the original of what is up, remembered across sessions in `state`
local current = ""

local function show(path)
    -- nothing up yet: the first one is there at once
    if (text["wall.a"] or "") == "" then
        text["wall.a"] = path
        text["wall.b"] = path
        return
    end
    if path == text[pick == 0 and "wall.a" or "wall.b"] then return end
    if pick == 0 then text["wall.b"] = path else text["wall.a"] = path end
    pick = 1 - pick
    fact["wall.pick"] = pick
end

-- the graded copy of a picture, made the first time; nil if it cannot be read
local function grade(src, done)
    local out = cache .. "/" .. (src:match("[^/]*$"):gsub("%.[^.]*$", "")) .. ".jpg"
    run("test", { "-s", out }, function(_, code)
        if code == 0 then
            done(out)
            return
        end
        local tmp = out .. ".png"
        run("magick", { src, "-auto-orient", tmp }, function(_, code)
            if code ~= 0 then
                done(nil)
                return
            end
            run("lutgen", { "apply", "--hald-clut", clut, tmp, "-o", out }, function(_, code)
                run("rm", { "-f", tmp }, nil, { output = false })
                done(code == 0 and out or nil)
            end)
        end)
    end)
end

local function wallpaper(src, failed)
    if changing or clut == "" or src == "" or src == current then return end
    changing = true
    grade(src, function(out)
        changing = false
        if not out then
            if failed then failed() end
            return
        end
        current = src
        run("tee", { state }, nil, { input = src .. "\n", output = false })
        show(out)
    end)
end

-- a random picture of the collection, other than the one up now; folders in it
-- (pictures set aside) have no extension and are passed over
if os and os.time then math.randomseed(os.time()) end
local function another()
    run("ls", { walls }, function(out, code)
        if code ~= 0 then return end
        local found = {}
        for name in out:gmatch("[^\n]+") do
            local path = walls .. "/" .. name
            local ext = (name:match("%.(%w+)$") or ""):lower()
            if (ext == "jpg" or ext == "jpeg" or ext == "png") and path ~= current then
                table.insert(found, path)
            end
        end
        if #found > 0 then wallpaper(found[math.random(#found)]) end
    end)
end

-- Where everything lives, then the CLUT from the palette (preserving
-- luminosity, so a photograph stays one), then what was up last time, or a new
-- one if it is gone. The graded copies are kept apart for each set of CLUT
-- options, so changing them grades everything again.
local LUT = { "-p", "carburetor", "-P", "-L", "0.5", "-r", "20", "-l", "10" }
local DIRS = [[
s="${XDG_STATE_HOME:-$HOME/.local/state}/pleamar/wallpaper"
c="${XDG_CACHE_HOME:-$HOME/.cache}/pleamar/wallpaper/$1"
mkdir -p "$s" "$c"
printf '%s\n' "$HOME/Pictures/walls/landscape_dump" "$s/current" "$c" "$c/clut.png"
]]
run("sh", { "-c", DIRS, "sh", (table.concat(LUT):gsub("[^%w.]", "")) }, function(out, code)
    if code ~= 0 then return end
    local lut
    walls, state, cache, lut = out:match("([^\n]+)\n([^\n]+)\n([^\n]+)\n([^\n]+)")
    local args = { "generate", table.unpack(LUT) }
    table.insert(args, "-o")
    table.insert(args, lut)
    run("lutgen", args, function(_, code)
        if code ~= 0 then return end
        clut = lut
        run("cat", { state }, function(saved)
            saved = saved:match("[^\n]*")
            if saved == "" then another() else wallpaper(saved, another) end
        end)
    end)
end)
on("wall_next", another)
on("wall_set", function() wallpaper(text["wall.req"]) end)

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
