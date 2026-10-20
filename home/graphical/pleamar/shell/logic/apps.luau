-- The launcher: desktop entries by fuzzy match weighted by use, a
-- calculator, commands from PATH run in a terminal or detached, and programs
-- from nixpkgs that are not installed (nix-locate), fetched and started.

return function(S)
    local apps = {}
    local commands = {}
    local usage = sys.ask("files.read", "usage.json", "json") or {}
    local rows = {}
    local nix = { query = "", hits = {}, searching = false, fetching = nil, failed = {} }
    local gen = 0

    local KIND = { app = 0, calc = 1, term = 2, run = 3, searching = 4, nix = 5, nixfail = 6 }

    local function shq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end

    -- A subsequence match: consecutive letters and word starts score more.
    local function fuzzy(q, s)
        s = s:lower()
        if q == "" then return 1 end
        local at, score, run, prev = 1, 0, 0, 0
        for i = 1, #q do
            local c = q:sub(i, i)
            local found = s:find(c, at, true)
            if not found then return nil end
            if found == prev + 1 then run += 1 else run = 0 end
            local start = found == 1 or s:sub(found - 1, found - 1):match("[%s%-_%.]") ~= nil
            score += 1 + run * 2 + (start and 3 or 0)
            prev, at = found, found + 1
        end
        if s:sub(1, #q) == q then score += 10 end
        return score - #s * 0.01
    end

    -- Uses weigh less as they age: 4 within a day, 2 a week, 1 a month.
    local function frecency(id)
        local u = usage[id]
        if not u then return 0 end
        local age = (os.time() - (u.last or 0)) / 86400
        local w = age < 1 and 4 or age < 7 and 2 or age < 30 and 1 or 0.5
        return (u.count or 0) * w
    end

    -- the calculator: + - * / % ^, parentheses and a few functions
    local fns = { sqrt = math.sqrt, sin = math.sin, cos = math.cos, tan = math.tan, log = math.log, exp = math.exp, abs = math.abs, floor = math.floor, ceil = math.ceil, round = function(x) return math.floor(x + 0.5) end }
    local consts = { pi = math.pi, e = math.exp(1) }
    local function calc(src)
        if not src:match("%d") or src:match("[^%d%s%+%-%*/%%%^%.%(%)%a,]") then return nil end
        local pos = 1
        local function peek() return src:match("^%s*(.)", pos) end
        local function take() local s, c = src:match("^(%s*)(.)", pos); pos += #s + 1; return c end
        local expr
        local function atom()
            local c = peek()
            if c == "(" then take(); local v = expr(); if take() ~= ")" then error("paren") end; return v end
            if c == "-" then take(); return -atom() end
            local num = src:match("^%s*(%d*%.?%d+)", pos)
            if num then pos = src:find(num, pos, true) + #num; return tonumber(num) end
            local name = src:match("^%s*(%a+)", pos)
            if name then
                pos = src:find(name, pos, true) + #name
                if consts[name] then return consts[name] end
                local f = fns[name]
                if not f or take() ~= "(" then error("name") end
                local v = expr()
                if take() ~= ")" then error("paren") end
                return f(v)
            end
            error("atom")
        end
        local function power()
            local v = atom()
            if peek() == "^" then take(); return v ^ power() end
            return v
        end
        local function term()
            local v = power()
            while true do
                local c = peek()
                if c == "*" then take(); v *= power()
                elseif c == "/" then take(); v /= power()
                elseif c == "%" then take(); v %= power()
                else return v end
            end
        end
        function expr()
            local v = term()
            while true do
                local c = peek()
                if c == "+" then take(); v += term()
                elseif c == "-" then take(); v -= term()
                else return v end
            end
        end
        local ok, v = pcall(expr)
        if not ok or peek() ~= nil or v ~= v or v == math.huge or v == -math.huge then return nil end
        if not src:match("[%+%-%*/%%%^%(]") then return nil end
        if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
        return (string.format("%.10g", v))
    end

    -- the list
    local function paint()
        local q = S.trim(text["ap.q"] or "")
        local lq = q:lower()
        rows = {}

        local value = calc(q)
        if value then
            table.insert(rows, { kind = KIND.calc, glyph = text["ic.calc"], title = value, detail = q, hint = "copy", value = value })
        end

        local scored = {}
        for _, a in ipairs(apps) do
            local s = fuzzy(lq, a.name or "")
            local alt = a.local_name and a.local_name ~= a.name and fuzzy(lq, a.local_name) or nil
            if alt then alt *= 0.6 end
            local best = s or alt
            if s and alt and alt > s then best = alt end
            if best then
                table.insert(scored, { a = a, score = best + frecency(a.id or a.name) * (lq == "" and 10 or 1) })
            end
        end
        table.sort(scored, function(x, y)
            if x.score ~= y.score then return x.score > y.score end
            return (x.a.name or "") < (y.a.name or "")
        end)
        for i = 1, math.min(#scored, 40 - #rows) do
            local a = scored[i].a
            table.insert(rows, { kind = KIND.app, icon = a.icon or "", title = a.name, detail = a.categories and a.categories:gsub(";.*", "") or "", hint = "launch", app = a })
        end

        -- A command line whose first word is a command: run it.
        local first = q:match("^(%S+)")
        if first and commands[first] then
            table.insert(rows, { kind = KIND.term, glyph = text["ic.terminal"], title = q, detail = "Run in terminal", hint = "run", line = q })
            table.insert(rows, { kind = KIND.run, glyph = text["ic.run"], title = q, detail = "Run detached", hint = "run", line = q })
        end

        -- Not installed, from nixpkgs.
        if nix.searching then
            table.insert(rows, { kind = KIND.searching, glyph = text["ic.search"], title = "Searching nixpkgs", detail = q, hint = "" })
        end
        for _, h in ipairs(nix.hits) do
            local busy = nix.fetching and nix.fetching.attr == h.attr
            local failed = nix.failed[h.attr]
            table.insert(rows, {
                kind = failed and KIND.nixfail or KIND.nix, glyph = text["ic.app"],
                title = h.bin .. "  (nixpkgs." .. h.attr .. ")",
                detail = busy and nix.fetching.status or failed or "Not installed: fetch and run",
                hint = busy and "cancel" or failed and "retry" or "fetch",
                progress = busy and nix.fetching.progress or -1, nixhit = h,
            })
        end

        -- The rest of the top app's name, ghosted after what was typed.
        local top = rows[1]
        if top and top.kind == KIND.app and lq ~= "" and top.title:lower():sub(1, #lq) == lq then
            text["ap.ghost"] = q .. top.title:sub(#q + 1)
        else
            text["ap.ghost"] = ""
        end
        model.aprows = rows
        fact["ap.n"] = #rows
    end

    -- nix-locate, a moment after typing stops
    local function locate()
        gen += 1
        local mine = gen
        local q = S.trim(text["ap.q"] or "")
        local prefix = q:match("^([%w%._%+%-]+)$")
        nix.hits = {}
        if not prefix or #prefix < 2 or #rows > 3 then nix.searching = false; return end
        nix.searching = true
        after(150, function()
            if mine ~= gen then return end
            run("sh", { "-c", 'nix-locate --at-root --type x --type s --regex "/bin/$1[^/]*$" 2>/dev/null | head -200', "sh", prefix }, function(out)
                if mine ~= gen then return end
                nix.searching = false
                local seen, per, hits = {}, {}, {}
                for attr, path in out:gmatch("([^%s]+)%s+[%d,]+%s+%a%s+(%S+)") do
                    attr = attr:gsub("%.out$", "")
                    local bin = path:match("/bin/([^/]+)$")
                    if bin and not commands[bin] and not seen[attr .. bin] then
                        seen[attr .. bin] = true
                        table.insert(hits, { attr = attr, bin = bin })
                    end
                end
                table.sort(hits, function(a, b)
                    local ae, be = a.bin == prefix, b.bin == prefix
                    if ae ~= be then return ae end
                    local an, bn = a.attr == a.bin, b.attr == b.bin
                    if an ~= bn then return an end
                    if #a.bin ~= #b.bin then return #a.bin < #b.bin end
                    return a.attr < b.attr
                end)
                for _, h in ipairs(hits) do
                    per[h.bin] = (per[h.bin] or 0) + 1
                    if per[h.bin] <= 2 and #nix.hits < 6 then table.insert(nix.hits, h) end
                end
                paint()
            end)
        end)
    end

    -- Builds it, telling how far along; then starts it.
    local function fetch(h)
        if nix.fetching then
            kill(nix.fetching.id, "term")
            local was = nix.fetching.attr
            nix.fetching = nil
            if was == h.attr then paint(); return end
        end
        nix.failed[h.attr] = nil
        local f = { attr = h.attr, status = "Starting", progress = -1, done = 0, expected = 0, out = nil }
        nix.fetching = f
        f.id = spawn("nix", { "build", "--no-link", "--print-out-paths", "--impure", "--log-format", "internal-json", "-v", "nixpkgs#" .. h.attr }, function(line)
            local j = line:match("^@nix (.*)$")
            if j then
                local ok, m = pcall(json.decode, j)
                if ok and m and m.action == "result" and m.type == 105 and m.fields then
                    local done, total = m.fields[1], m.fields[2]
                    if total and total > 0 then f.progress = done / total end
                    f.status = string.format("Downloading %.1f / %.1f MiB", (done or 0) / 1048576, (total or 0) / 1048576)
                    paint()
                elseif ok and m and m.action == "start" and m.type == 105 then
                    f.status = "Building " .. (m.text or "")
                    paint()
                end
            elseif line:match("^/nix/store/") then
                f.out = S.trim(line)
            end
        end, function(_, code)
            if nix.fetching ~= f then return end
            nix.fetching = nil
            if code == 0 and f.out then
                S.spawn(shq(f.out .. "/bin/" .. h.bin))
                fact.page = 0
                fact.held = false
            else
                nix.failed[h.attr] = "Could not fetch " .. h.attr
            end
            paint()
        end, { errors = true, env = { NIXPKGS_ALLOW_UNFREE = "1" } })
        paint()
    end

    local function used(id)
        local u = usage[id] or { count = 0 }
        u.count += 1
        u.last = os.time()
        usage[id] = u
        sys.call("files.write", "usage.json", usage)
    end

    local function close()
        fact.page = 0
        fact.held = false
    end

    on("ap_go", function(i)
        local r = rows[i + 1]
        if not r then return end
        if r.kind == KIND.app then
            used(r.app.id or r.app.name)
            sys.call("apps.launch", r.app.exec)
            close()
        elseif r.kind == KIND.calc then
            run("wl-copy", { "--", r.value }, nil, { output = false })
            close()
        elseif r.kind == KIND.term then
            S.spawn("env LAUNCHER_RUN=" .. shq(r.line) .. " rio")
            close()
        elseif r.kind == KIND.run then
            S.spawn(r.line)
            close()
        elseif r.nixhit then
            fetch(r.nixhit)
        end
    end)

    on("ap_accept", function()
        local g = text["ap.ghost"] or ""
        if g ~= "" then text["ap.q"] = g; paint() end
    end)

    on("text:ap.q", function() paint(); locate() end)

    -- Every command a shell would know, gathered each time the launcher opens.
    local function scan()
        run("sh", { "-c", 'IFS=:; for d in $PATH; do ls "$d" 2>/dev/null; done' }, function(out)
            local c = {}
            for name in out:gmatch("[^\n]+") do c[name] = true end
            commands = c
        end)
    end

    on("fact:page", function(p)
        if p == 3 then
            text["ap.q"] = ""
            nix.hits, nix.searching = {}, false
            scan()
            paint()
        end
    end)

    sys.watch("apps", function(list)
        apps = list or {}
        paint()
    end)
    scan()
end
