-- Toasts: each notice that arrives is shown beside the rail for a while,
-- then leaves; a press dismisses it for good. Held back while the control
-- centre is open, and for the first second after starting.

return function(S)
    local TIMEOUT, MAX = 10, 6
    local warm = false
    after(1000, function() warm = true end)
    local seen = {}
    local cards = {}

    local function paint()
        local rows = {}
        for i, c in ipairs(cards) do
            rows[i] = { app = c.app, title = c.title, body = c.body, hasbody = c.body ~= "", urgency = c.urgency, gone = c.gone }
        end
        model["ts.cards"] = rows
    end

    local function remove(id)
        for i, c in ipairs(cards) do
            if c.id == id then table.remove(cards, i) break end
        end
        paint()
    end

    -- Faded first, then taken out of the column.
    local function leave(id)
        for _, c in ipairs(cards) do
            if c.id == id and not c.gone then
                c.gone = true
                paint()
                after(150, function() remove(id) end)
            end
        end
    end

    local function quiet() return fact.page == 1 or not warm end

    S.onNotifications(function(list)
        local live = {}
        for _, n in ipairs(list or {}) do
            live[n.id] = true
            if not seen[n.id] then
                seen[n.id] = true
                if not quiet() then
                    table.insert(cards, 1, {
                        id = n.id, app = n.app or "", title = n.title or "",
                        body = (n.body or ""):gsub("<[^>]*>", ""),
                        urgency = tonumber(n.urgency) or 1, gone = false,
                    })
                    while #cards > MAX do table.remove(cards) end
                    if (tonumber(n.urgency) or 1) < 2 then
                        local secs = tonumber(n.timeout)
                        if not secs or secs <= 0 then secs = TIMEOUT end
                        local id = n.id
                        after(secs * 1000, function() leave(id) end)
                    end
                end
            end
        end
        -- Dismissed elsewhere (the control centre): gone here too.
        for _, c in ipairs(cards) do
            if not live[c.id] then leave(c.id) end
        end
        paint()
    end)

    on("ts_dismiss", function(i)
        local c = cards[i + 1]
        if not c then return end
        sys.call("notifications.dismiss", c.id)
        leave(c.id)
    end)

    -- Opening the control centre takes every toast away.
    on("fact:page", function(p)
        if p == 1 then
            for _, c in ipairs(cards) do c.gone = true end
            cards = {}
            paint()
        end
    end)

    -- the song: shown when the track changes, for ten seconds
    local key, timer = nil, nil
    local function hide()
        if fact["ts.songhover"] then
            timer = after(1000, hide)
        else
            fact["ts.song"] = false
        end
    end
    sys.watch("media", function(m)
        if not m or (m.player or "") == "" or (m.title or "") == "" then return end
        local k = (m.player or "") .. "\n" .. (m.title or "")
        if k == key then return end
        local first = key == nil
        key = k
        if first or not m.playing or quiet() then return end
        fact["ts.song"] = true
        if timer then cancel(timer) end
        timer = after(10000, hide)
    end)
end
