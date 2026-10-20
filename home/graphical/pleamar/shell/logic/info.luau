-- The system page: who this machine is, once; heat, battery and history from
-- the meters while the page is shown; the busiest processes every two
-- seconds, also only while shown.

return function(S)
    local N = 60
    local SERIES = { "c", "m", "g", "r", "w", "d", "u" }
    local hist = {}
    for _, s in ipairs(SERIES) do hist[s] = {} end
    local deg = utf8.char(0xb0)
    local dot = " " .. utf8.char(0xb7) .. " "
    local down, up = utf8.char(0x2193), utf8.char(0x2191)
    local shown = false
    local cputemp_path = nil
    local cpuc, gpuc = 0, nil
    local memTotal = 0

    local UNITS = { "B", "KB", "MB", "GB", "TB" }
    local function scale(n)
        local i = 0
        n = math.max(0, n or 0)
        while n >= 1024 and i < #UNITS - 1 do
            n = n / 1024
            i = i + 1
        end
        return i
    end
    -- as Quickshell's formatBytesAt: whole below KB or past 100, else a decimal
    local function bytesAt(n, i)
        n = math.max(0, n or 0) / 1024 ^ i
        local f = (i == 0 or n >= 100) and string.format("%d", math.floor(n + 0.5)) or string.format("%.1f", n)
        return f .. " " .. UNITS[i + 1]
    end
    local function bytes(n) return bytesAt(n, scale(n)) end
    local function span(seconds)
        local d = math.floor(seconds / 86400)
        local h = math.floor(seconds % 86400 / 3600)
        local m = math.floor(seconds % 3600 / 60)
        if d > 0 then return d .. "d " .. h .. "h" end
        if h > 0 then return h .. "h " .. m .. "m" end
        return m .. "m"
    end
    -- Vendor strings trimmed to the part that tells one apart.
    local function tidy(s)
        s = (s or ""):gsub("%((R)%)", ""):gsub("%(TM%)", ""):gsub("%(tm%)", "")
        for _, w in ipairs({ "CPU", "GPU", "Intel", "AMD", "NVIDIA", "GeForce" }) do
            s = (" " .. s .. " "):gsub("([%s])" .. w .. "([%s])", "%1%2")
        end
        s = s:gsub("@.*$", ""):gsub("%s+%-%s+.*$", ""):gsub("%s+", " ")
        return S.trim(s)
    end
    local function fahrenheit(c) return math.floor(c * 9 / 5 + 32 + 0.5) end

    -- once: who and what
    run("sh", { "-c", [[
        id -un; hostname; . /etc/os-release; echo "$PRETTY_NAME"; uname -r
        v=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null); p=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
        echo "$v $p"
        awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo
        nproc
        nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1
        readlink /nix/var/nix/profiles/system
        stat -c %Y /nix/var/nix/profiles/system
        date +%s
        nixos-version
        readlink -f "$(command -v pleamar-wm)"
        pleamar-wm --version
    ]] }, function(out)
        local l = {}
        for line in (out .. "\n"):gmatch("([^\n]*)\n") do l[#l + 1] = line end
        text["inf.user"], text["inf.host"] = l[1] or "", l[2] or ""
        text["inf.os"] = l[3] or ""
        text["inf.kernel"] = (l[4] or "") ~= "" and ("Linux " .. l[4]) or ""
        text["inf.model"] = tidy(l[5])
        text["inf.cpuname"] = tidy(l[6]) .. dot .. S.trim(l[7]) .. "T"
        text["inf.gpuname"] = tidy(l[8])
        local now = tonumber(l[11]) or 0
        local gen = (l[9] or ""):match("system%-(%d+)%-link")
        local stamp = tonumber(l[10])
        text["inf.gen"] = gen and ("#" .. gen .. (stamp and (dot .. span(math.max(0, now - stamp)) .. " ago") or "")) or ""
        -- 26.11.20261014.55bfb4d (Zokor)
        local y, m, d, rev = (l[12] or ""):match("%d+%.%d+%.(%d%d%d%d)(%d%d)(%d%d)%.(%w+)")
        if y then
            local built = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
            local days = math.floor((now - built) / 86400)
            text["inf.nixpkgs"] = rev .. dot .. (days <= 0 and "today" or days == 1 and "1 day ago" or (days .. " days ago"))
        end
        local wmv = (l[13] or ""):match("pleamar%-wm%-([%d%.]+)")
        text["inf.wm"] = wmv and ("pleamar-wm " .. wmv) or "pleamar-wm"
        local pv = (l[14] or ""):match("pleamar ([%d%.]+)")
        text["inf.shell"] = pv and ("pleamar " .. pv) or "pleamar"
    end)

    -- CPU package temperature, found once among the hwmon sensors.
    run("sh", { "-c", 'for d in /sys/class/hwmon/hwmon*; do [ "$(cat "$d/name")" = coretemp ] && echo "$d/temp1_input" && break; done' }, function(out)
        local p = S.trim(out)
        if p ~= "" then cputemp_path = p end
    end)

    local function uptime()
        run("cat", { "/proc/uptime" }, function(out)
            text["inf.uptime"] = "up " .. span(tonumber(out:match("^(%S+)")) or 0)
        end)
    end
    uptime()
    every(30000, uptime)

    local function diskuse()
        run("stat", { "-f", "-c", "%b %a %S", "/" }, function(out)
            local b, a, sz = out:match("(%d+)%s+(%d+)%s+(%d+)")
            if not b then return end
            b, a, sz = tonumber(b), tonumber(a), tonumber(sz)
            fact["inf.disk"] = b > 0 and (b - a) / b or 0
            text["inf.diskuse"] = bytes((b - a) * sz) .. " / " .. bytes(b * sz)
        end)
    end
    diskuse()
    every(60000, diskuse)

    -- Heat: each part on the 30 to 100 C scale, which sets the heading's
    -- tint; the bar is their average, 100 to 230 F.
    local function heat()
        text["inf.cputemp"] = fahrenheit(cpuc) .. deg
        text["inf.gputemp"] = gpuc and (fahrenheit(gpuc) .. deg) or ""
        local hot = math.max(cpuc, gpuc or 0)
        fact["inf.heat"] = math.max(0, math.min(1, (hot - 30) / 70))
        fact["inf.heatbar"] = math.max(0, math.min(1, (fahrenheit(gpuc and (cpuc + gpuc) / 2 or cpuc) - 100) / 130))
    end

    -- battery: capacity from the service, the rest from sysfs
    sys.watch("battery", function(b)
        fact["inf.batok"] = b.present == true
        fact["inf.bat.pct"] = b.percent or 0
        fact["inf.bat.chg"] = b.charging == true
    end)
    local function battery()
        run("sh", { "-c", "cat /sys/class/power_supply/BAT*/uevent 2>/dev/null" }, function(out)
            local v = {}
            for k, val in out:gmatch("POWER_SUPPLY_([%u_]+)=([^\n]*)") do v[k] = val end
            if not v.STATUS then return end
            local volt = (tonumber(v.VOLTAGE_NOW) or 0) / 1e6
            local now = tonumber(v.ENERGY_NOW) or (tonumber(v.CHARGE_NOW) or 0) * volt
            local full = tonumber(v.ENERGY_FULL) or (tonumber(v.CHARGE_FULL) or 0) * volt
            local design = tonumber(v.ENERGY_FULL_DESIGN) or (tonumber(v.CHARGE_FULL_DESIGN) or 0) * volt
            local watts = (tonumber(v.POWER_NOW) or (tonumber(v.CURRENT_NOW) or 0) * volt) / 1e6
            local pct = tonumber(v.CAPACITY) or fact["inf.bat.pct"] or 0
            local st = v.STATUS
            text["inf.bat.state"] = st == "Charging" and "charging" or st == "Discharging" and "on battery"
                or (st == "Full" or (st == "Not charging" and pct >= 95)) and "full"
                or st == "Not charging" and "plugged in" or ""
            local parts = {}
            if watts > 0.05 and (st == "Charging" or st == "Discharging") then
                local hours = st == "Charging" and (full - now) / 1e6 / watts or now / 1e6 / watts
                parts[#parts + 1] = span(hours * 3600) .. (st == "Charging" and " to full" or " left")
            end
            if watts > 0.05 then parts[#parts + 1] = string.format("%.1f W", watts) end
            text["inf.bat.time"] = #parts > 0 and table.concat(parts, dot) or "holding charge"
            text["inf.bat.health"] = design > 0 and string.format("health %d%%", math.floor(full / design * 100 + 0.5)) or ""
        end)
    end

    -- History, as Quickshell's sparklines draw it: each series scaled to the
    -- range its window holds, a tenth of headroom over the peak, capped at
    -- what the reading can reach; a flat window centred in a range of its own.
    local LIMIT = { c = 100, g = 100 }
    local function publish()
        local n = #hist.c
        fact["inf.s.first"] = N - n
        for _, s in ipairs(SERIES) do
            local h = hist[s]
            if #h > 0 then
                local lo, hi = math.huge, 0
                for _, v in ipairs(h) do lo, hi = math.min(lo, v), math.max(hi, v) end
                local room = math.max((hi - lo) * 0.1, hi * 0.1, 1)
                local ceil = math.min(LIMIT[s] or (s == "m" and memTotal > 0 and memTotal) or math.huge, hi + room)
                local floor = math.max(0, lo - (hi > lo and 0 or room))
                local range = math.max(ceil - floor, 1e-4)
                local off = N - #h
                for k = 0, N - 1 do
                    local v = h[math.max(k - off, 0) + 1]
                    fact["inf.s." .. s .. "." .. k] = math.max(0, math.min(1, (v - floor) / range))
                end
            end
        end
    end
    local function push(s, v)
        local h = hist[s]
        if #h >= N then table.remove(h, 1) end
        h[#h + 1] = v
    end

    local last_push = -10
    S.meters.listen(function(m)
        if not shown then return end
        memTotal = m.memTotal or 0
        if m.cpu then text["inf.cpufig"] = string.format("%d%%", math.floor(m.cpu * 100 + 0.5)) end
        text["inf.memfig"] = bytes(m.memUsed)
        text["inf.memtot"] = bytes(m.memTotal)
        local gpu_on = (m.gpu or -1) >= 0
        fact["inf.gpu.on"] = gpu_on
        if gpu_on then
            text["inf.gpufig"] = string.format("%d%%", math.floor(m.gpu * 100 + 0.5))
            fact["inf.vram"] = (m.gpuMemTotal or 0) > 0 and m.gpuMemUsed / m.gpuMemTotal or 0
            text["inf.vramtext"] = "VRAM  " .. bytes((m.gpuMemUsed or 0) * 1048576) .. " / " .. bytes((m.gpuMemTotal or 0) * 1048576)
            gpuc = m.gpuTemp or 0
        else
            gpuc = nil
        end
        if m.down then
            -- each pair on one scale, so the two read against each other
            local ns, ds = scale(math.max(m.down, m.up)), scale(math.max(m.read, m.write))
            text["inf.down"] = down .. " " .. bytesAt(m.down, ns) .. "/s"
            text["inf.up"] = up .. " " .. bytesAt(m.up, ns) .. "/s"
            text["inf.read"] = down .. " " .. bytesAt(m.read, ds) .. "/s"
            text["inf.write"] = up .. " " .. bytesAt(m.write, ds) .. "/s"
        end
        if cputemp_path then
            run("cat", { cputemp_path }, function(out)
                local mc = tonumber(S.trim(out))
                if mc then cpuc = mc / 1000 end
                heat()
            end)
        else
            heat()
        end
        local now = os.clock()
        if now - last_push >= 1.9 and m.down and m.cpu then
            last_push = now
            push("c", m.cpu * 100)
            push("m", m.memUsed or 0)
            push("g", math.max(m.gpu or 0, 0) * 100)
            push("r", m.read or 0)
            push("w", m.write or 0)
            push("d", m.down or 0)
            push("u", m.up or 0)
            publish()
            battery()
        end
    end)

    -- processes: the busiest by CPU, then by memory
    local function name(s)
        -- the wrapper's comm, cut to 15 characters, back to the program's name
        s = s:gsub("^%.", ""):gsub("%-wra?p?p?e?d?$", ""):gsub("%-unwr?a?p?p?e?d?$", "")
        return s
    end
    local procs_busy = false
    local function procs()
        if not shown or procs_busy then return end
        procs_busy = true
        run("sh", { "-c", "top -b -n 2 -d 0.5 -o %CPU -w 512 -e k; echo; nproc" }, function(out)
            procs_busy = false
            local ncpu = tonumber(out:match("(%d+)%s*$")) or 1
            -- The second iteration: the first measures since boot.
            local last = out:match(".*\n%s*PID%s+USER[^\n]*\n(.*)") or ""
            local rows = {}
            for line in last:gmatch("[^\n]+") do
                local user, res, cpu, cmd = line:match("^%s*%d+%s+(%S+)%s+%S+%s+%S+%s+%S+%s+(%S+)%s+%S+%s+%S+%s+([%d%.]+)%s+[%d%.]+%s+%S+%s+(.+)$")
                if user then
                    local kb = tonumber((res:gsub("[mgt]$", ""))) or 0
                    if res:match("m$") then kb = kb * 1024 elseif res:match("g$") then kb = kb * 1048576 end
                    rows[#rows + 1] = { name = name(S.trim(cmd)), user = user, kb = kb, cpu = tonumber(cpu) / ncpu }
                end
            end
            local list, seen, busy = {}, {}, 0
            for _, r in ipairs(rows) do
                if r.cpu > 0 then busy = busy + 1 end
            end
            for i = 1, math.min(12, #rows) do
                if rows[i].cpu <= 0 then break end
                list[#list + 1] = rows[i]
                seen[rows[i]] = true
            end
            table.sort(rows, function(a, b) return a.kb > b.kb end)
            for _, r in ipairs(rows) do
                if #list >= 24 then break end
                if not seen[r] then list[#list + 1] = r end
            end
            local m = {}
            for i, r in ipairs(list) do
                m[i] = { name = r.name, user = r.user, root = r.user == "root" and 1 or 0, mem = bytes(r.kb * 1024), cpu = r.cpu / 100, cpus = string.format("%.1f%%", r.cpu) }
            end
            model.infprocs = m
            text["inf.busy"] = busy .. " busy"
        end)
    end
    every(2000, procs)

    local function show(v)
        local now_shown = v == 2
        if now_shown == shown then return end
        shown = now_shown
        S.meters.watch(shown)
        if shown then
            battery()
            procs()
        end
    end
    on("fact:page", show)
    show(fact.page)
end
