-- This desktop from a browser elsewhere (pleamar-wm remote), run as the
-- pleamar-remote user service: the control centre's tile starts and stops it.
return function(S)
    local UNIT = "pleamar-remote.service"

    local function check()
        run("systemctl", { "--user", "is-active", UNIT }, function(out)
            fact["rm.on"] = S.trim(out) == "active"
        end)
    end

    on("rm_toggle", function()
        local verb = fact["rm.on"] and "stop" or "start"
        fact["rm.on"] = not fact["rm.on"]
        run("systemctl", { "--user", verb, UNIT }, check, { output = false })
    end)

    -- started or stopped elsewhere too, or failed on its own
    check()
    every(5000, check)
end
