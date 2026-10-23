-- The control centre's Displays card: the monitors' places. Read from the compositor, moved
-- with `pleamar-wm output NAME at X,Y`, and kept in the state directory,
-- from where they are put back when the shell starts (over session.conf's).

return function(S)
    local DIR = [[d="${XDG_STATE_HOME:-$HOME/.local/state}/pleamar"]]
    -- How close, in desktop units, an edge has to come to another's to be
    -- lined up with it; and how much of an edge two monitors share at least.
    local NEAR, SHARE = 60, 100

    local outs = {}

    local function refresh(done)
        run("pleamar-wm", { "hyprctl", "monitors" }, function(out, code)
            if code ~= 0 then
                if done then done(false) end
                return
            end
            outs = {}
            local pat = "Monitor (%S+) %(ID %d+%):%s*(%d+)x(%d+)@[%d.]+ at (%-?%d+)x(%-?%d+)%s*scale: ([%d.]+)"
            for name, pw, ph, x, y, sc in out:gmatch(pat) do
                local scale = tonumber(sc)
                table.insert(outs, {
                    name = name, x = tonumber(x), y = tonumber(y),
                    w = math.floor(tonumber(pw) / scale + 0.5), h = math.floor(tonumber(ph) / scale + 0.5),
                })
            end
            -- the map: all of them, and a sixth of the widest around
            local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
            local room, wide = 0, nil
            for _, o in ipairs(outs) do
                x0, y0 = math.min(x0, o.x), math.min(y0, o.y)
                x1, y1 = math.max(x1, o.x + o.w), math.max(y1, o.y + o.h)
                room = math.max(room, o.w / 6, o.h / 6)
                if not wide or o.w / o.h > wide.w / wide.h then wide = o end
            end
            if #outs > 0 then
                -- the map is shaped as the widest of them
                fact["pf.aw"] = wide.w
                fact["pf.ah"] = wide.h
                fact["pf.minx"] = x0 - room
                fact["pf.miny"] = y0 - room
                fact["pf.spanw"] = x1 - x0 + 2 * room
                fact["pf.spanh"] = y1 - y0 + 2 * room
            end
            model.pfouts = outs
            local names = {}
            for _, o in ipairs(outs) do table.insert(names, o.name) end
            text["pf.status"] = table.concat(names, ", ")
            if done then done(true) end
        end)
    end

    local function overlaps(a, b)
        return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
    end

    -- Along one edge of another: the span it may slide over, still sharing
    -- SHARE of the edge, and lined up with its start, middle or end if near.
    local function along(v, start, len, olen)
        v = math.max(start - len + SHARE, math.min(v, start + olen - SHARE))
        for _, c in ipairs({ start, start + (olen - len) / 2, start + olen - len }) do
            if math.abs(v - c) < NEAR then return c end
        end
        return v
    end

    -- Where the one being dragged goes from (nx, ny): against the nearest
    -- edge of another, without covering any.
    local function snap(d, nx, ny)
        local best, bestd
        for _, o in ipairs(outs) do
            if o ~= d then
                local ys, xs = along(ny, o.y, d.h, o.h), along(nx, o.x, d.w, o.w)
                for _, c in ipairs({
                    { x = o.x + o.w, y = ys }, { x = o.x - d.w, y = ys },
                    { x = xs, y = o.y + o.h }, { x = xs, y = o.y - d.h },
                }) do
                    local r = { x = math.floor(c.x + 0.5), y = math.floor(c.y + 0.5), w = d.w, h = d.h }
                    local free = true
                    for _, p in ipairs(outs) do
                        if p ~= d and overlaps(r, p) then free = false end
                    end
                    local dist = (r.x - nx) ^ 2 + (r.y - ny) ^ 2
                    if free and (not best or dist < bestd) then best, bestd = r, dist end
                end
            end
        end
        return best or { x = math.floor(nx + 0.5), y = math.floor(ny + 0.5) }
    end

    local function dragged()
        local i = fact["pf.drag"] or -1
        return i >= 0 and outs[i + 1] or nil
    end
    local function follow()
        local d = dragged()
        if not d then return end
        local p = snap(d, fact["pf.nx"] or d.x, fact["pf.ny"] or d.y)
        fact["pf.sx"] = p.x
        fact["pf.sy"] = p.y
    end
    on("fact:pf.nx", follow)
    on("fact:pf.ny", follow)

    -- Each place asked in turn; those that would cover another (one still in
    -- the way, about to move) are asked once more after the rest.
    local function apply(list, done, again)
        local failed, i = {}, 0
        local function step()
            i = i + 1
            local p = list[i]
            if not p then
                if #failed > 0 and not again then return apply(failed, done, true) end
                -- the window manager lines up windows across the edges by these
                S.wm("emit shell_hello")
                return done(failed)
            end
            run("pleamar-wm", { "output", p.name, "at", p.x .. "," .. p.y }, function(_, code)
                if code ~= 0 then table.insert(failed, p) end
                step()
            end, { output = false })
        end
        step()
    end

    local function save()
        local lines = {}
        for _, o in ipairs(outs) do table.insert(lines, o.name .. " " .. o.x .. " " .. o.y) end
        run("sh", { "-c", DIR .. [[; mkdir -p "$d" && printf '%s\n' "$@" > "$d/outputs"]], "sh", table.unpack(lines) }, nil, { output = false })
    end

    -- What differs from where they are now, among the monitors there are.
    local function changes(want)
        local list = {}
        for _, o in ipairs(outs) do
            local p = want[o.name]
            if p and (p.x ~= o.x or p.y ~= o.y) then table.insert(list, { name = o.name, x = p.x, y = p.y }) end
        end
        return list
    end

    local function settle(failed)
        text["pf.msg"] = #failed > 0 and ("could not place " .. failed[1].name .. ": it would cover another") or ""
        refresh(function()
            fact["pf.drag"] = -1
        end)
    end

    on("pf_drop", function(i)
        local d = outs[i + 1]
        if not d then
            fact["pf.drag"] = -1
            return
        end
        local x, y = fact["pf.sx"] or d.x, fact["pf.sy"] or d.y
        if x == d.x and y == d.y then
            fact["pf.drag"] = -1
            return
        end
        apply({ { name = d.name, x = x, y = y } }, function(failed)
            settle(failed)
            if #failed == 0 then refresh(save) end
        end)
    end)

    -- Back to session.conf's places, and nothing kept.
    on("pf_reset", function()
        run("sh", { "-c", [[cat "${XDG_CONFIG_HOME:-$HOME/.config}/pleamar/session.conf"]] }, function(conf)
            local want = {}
            for name, x, y in (conf or ""):gmatch("monitor (%S+)[^\n]- at (%-?%d+),(%-?%d+)") do
                want[name] = { x = tonumber(x), y = tonumber(y) }
            end
            run("sh", { "-c", DIR .. [[; rm -f "$d/outputs"]] }, function()
                apply(changes(want), settle)
            end, { output = false })
        end)
    end)

    -- At start, the places kept, once the compositor answers.
    local function restore(tries)
        refresh(function(ok)
            if not ok then
                if tries > 0 then after(1000, function() restore(tries - 1) end) end
                return
            end
            run("sh", { "-c", DIR .. [[; cat "$d/outputs" 2>/dev/null]] }, function(kept)
                local want = {}
                for name, x, y in (kept or ""):gmatch("(%S+) (%-?%d+) (%-?%d+)") do
                    want[name] = { x = tonumber(x), y = tonumber(y) }
                end
                local list = changes(want)
                if #list > 0 then apply(list, settle) end
            end)
        end)
    end
    restore(10)

    on("fact:page", function(p)
        if p == 1 then refresh() end
    end)
end
