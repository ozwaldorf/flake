-- The desk's logic. Each piece lives in a module under logic/ that returns a
-- function taking the shared table below; a module that is missing or broken
-- is reported and the rest carry on.

local S = {}

-- Something for the window manager's scene (pleamar-wm's own session).
function S.wm(...)
    run("pleamar", { "--say", "wm", ... }, nil, { output = false })
end

-- Starts a program loose from the shell, so it outlives it.
function S.spawn(cmd)
    run("setsid", { "-f", "sh", "-c", cmd }, nil, { output = false })
end

function S.trim(s)
    return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

for _, name in ipairs({ "icons", "meters", "settings", "info", "apps", "clipboard", "keys", "taskbar", "toasts", "recorder" }) do
    local ok, mod = pcall(require, "logic/" .. name)
    if not ok then
        log("module " .. name .. ": " .. tostring(mod))
    elseif type(mod) == "function" then
        local ran, err = pcall(mod, S)
        if not ran then log("module " .. name .. ": " .. tostring(err)) end
    end
end

-- the window manager
-- a workspace on a monitor: monitor + 4 * workspace
on("ws_go", function(code) S.wm("emit workspace_on " .. code) end)
-- the room the rail and drawer take on a monitor: s + 4 * (px + 4096)
on("room_report", function(code)
    local s = code % 4
    S.wm("fact room." .. s .. " " .. ((code - s) / 4 - 4096))
end)
-- the overview on a monitor, opened or closed: monitor + 4 to open
on("wm_overview", function(code)
    local s = code % 4
    S.wm((code >= 4 and "emit overview_on " or "emit overview_off ") .. s)
end)
-- Ask it for the state it reports, now that someone is listening.
S.wm("emit shell_hello")
-- And again a moment later: at login the window manager can still be
-- starting, or this file slow enough to be cut off, and what is reported
-- only on a change (the monitors' sizes) would never arrive.
after(3000, function() S.wm("emit shell_hello") end)

-- Kept until dismissed: the list of notifications is the history. The
-- service has to be watched before it can be told so.
sys.watch("notifications", function() end)
pcall(sys.call, "notifications.keep", true)
