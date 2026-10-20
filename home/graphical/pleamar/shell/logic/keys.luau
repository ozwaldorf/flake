-- The key bindings page: the generated list, grouped under headers, filtered
-- by label, key or group as typed.

return function()
    local ok, binds = pcall(require, "logic/keybinds")
    if not ok then binds = {} end

    -- Key names as a person reads them.
    local names = { question = "?", grave = "`", Return = "Enter", Escape = "Esc", space = "Space", Print = "PrtSc" }

    local function caps(key)
        local out = {}
        for part in key:gmatch("[^+]+") do
            table.insert(out, names[part] or (#part == 1 and part:upper()) or part)
        end
        return out
    end

    local function paint()
        local q = (text["ky.q"] or ""):lower()
        local rows, group = {}, nil
        for _, b in ipairs(binds) do
            local hay = (b.label .. " " .. b.key .. " " .. b.group):lower()
            if q == "" or hay:find(q, 1, true) then
                if b.group ~= group then
                    group = b.group
                    table.insert(rows, { header = true, label = group, caps = 0 })
                end
                local c = caps(b.key)
                table.insert(rows, { header = false, label = b.label, k1 = c[1] or "", k2 = c[2] or "", k3 = c[3] or "", k4 = c[4] or "", caps = #c })
            end
        end
        model.kyrows = rows
        fact["ky.n"] = #rows
    end

    on("text:ky.q", paint)
    on("fact:page", function(p)
        if p == 5 then
            text["ky.q"] = ""
            paint()
        end
    end)
    paint()
end
