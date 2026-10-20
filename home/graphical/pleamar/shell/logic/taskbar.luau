-- The task bar's windows, in the order the window manager keeps them: it
-- sends rows in tb.data (record separator between rows, unit separator
-- between fields: slot, focused, urgent, monitor, app, title) and then
-- tb_data.

return function(S)
    on("tb_data", function()
        local rows, counts = {}, { 0, 0, 0, 0 }
        for line in (text["tb.data"] or ""):gmatch("[^\30]+") do
            if #rows >= 32 then break end
            local f = {}
            for field in (line .. "\31"):gmatch("([^\31]*)\31") do f[#f + 1] = field end
            local m = tonumber(f[4]) or 0
            counts[m + 1] = (counts[m + 1] or 0) + 1
            rows[#rows + 1] = {
                slot = tonumber(f[1]) or 0,
                active = f[2] == "1",
                urgent = f[3] == "1",
                mon = m,
                icon = f[5] or "",
                title = (f[6] ~= nil and f[6] ~= "") and f[6] or (f[5] or ""),
            }
        end
        model["tb.wins"] = rows
        for k = 0, 3 do fact["tb.n." .. k] = counts[k + 1] or 0 end
    end)

    on("tb_go", function(i)
        local w = model["tb.wins"][i + 1]
        if w then S.wm("emit tb_focus " .. w.slot) end
    end)
end
