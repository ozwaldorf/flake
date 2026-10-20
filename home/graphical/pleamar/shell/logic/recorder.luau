-- Screen recording: a region picked with slurp, recorded by
-- gpu-screen-recorder until asked again (`emit rec_toggle`).

return function(S)
    local id, ticker = nil, nil
    local picking = false

    local function stopped()
        id = nil
        if ticker then cancel(ticker) ticker = nil end
        fact["rec.on"] = false
        fact["rec.secs"] = 0
    end

    local function start(region)
        local dir = sys.ask("env", "XDG_VIDEOS_DIR") or ((sys.ask("env", "HOME") or "") .. "/Videos")
        local file = dir .. "/screen-recording-" .. os.date("%Y%m%d-%H%M%S") .. ".mp4"
        id = spawn("sh", {
            "-c", 'mkdir -p "$(dirname "$2")" && exec gpu-screen-recorder -w region -region "$1" -f 60 -cursor yes -o "$2"',
            "sh", region, file,
        }, function() end, function(_, code)
            if code ~= 0 then log("recorder: gpu-screen-recorder exited " .. tostring(code)) end
            stopped()
        end)
        fact["rec.on"] = true
        fact["rec.secs"] = 0
        ticker = every(1000, function() fact["rec.secs"] = fact["rec.secs"] + 1 end)
    end

    on("rec_toggle", function()
        if id then
            kill(id, "int")
            return
        end
        if picking then return end
        picking = true
        run("slurp", { "-o", "-f", "%wx%h+%x+%y" }, function(out, code)
            picking = false
            local region = S.trim(out)
            if code == 0 and region ~= "" then start(region) end
        end)
    end)
end
