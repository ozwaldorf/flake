-- Load sampling for the rail's meters, from /proc and nvidia-smi. Every two
-- seconds, or every half second while someone looks (`meters.fast`, or a
-- module that asked through S.meters.watch). Modules that want each sample
-- (the system page's charts) subscribe with S.meters.listen.

return function(S)
    local M = { listeners = {}, watchers = 0, last = nil }
    S.meters = M

    function M.listen(fn) table.insert(M.listeners, fn) end
    function M.watch(on) M.watchers = math.max(0, M.watchers + (on and 1 or -1)) end

    local prev = {}
    local gpu = { util = -1, memUsed = 0, memTotal = 0, temp = 0 }
    local rootdisk = nil
    local NET_CEIL = 12.5e6 -- 100 Mbit/s, in bytes

    -- The whole disk under /, for its I/O counters.
    run("sh", { "-c", [[lsblk -nso NAME,TYPE "$(findmnt -no SOURCE /)" | awk '$2=="disk"{print $1; exit}']] }, function(out)
        rootdisk = S.trim(out):gsub("^[^%w]+", "")
    end)

    -- nvidia-smi keeps writing a line every two seconds; restarted if it dies
    -- after having worked.
    local function gpuwatch()
        local worked = false
        spawn("nvidia-smi", { "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits", "-lms", "2000" }, function(line)
            local u, mu, mt, t = line:match("(%d+),%s*(%d+),%s*(%d+),%s*(%d+)")
            if u then
                worked = true
                gpu = { util = tonumber(u) / 100, memUsed = tonumber(mu), memTotal = tonumber(mt), temp = tonumber(t) }
            end
        end, function()
            gpu.util = -1
            if worked then after(5000, gpuwatch) end
        end)
    end
    gpuwatch()

    local function sample()
        run("cat", { "/proc/stat", "/proc/meminfo", "/proc/net/dev", "/proc/diskstats" }, function(out)
            local s = {}

            local user, nice, system, idle, iowait, irq, softirq, steal = out:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
            if user then
                local busy = user + nice + system + irq + softirq + steal
                local total = busy + idle + iowait
                if prev.total then
                    local dt = total - prev.total
                    s.cpu = dt > 0 and (busy - prev.busy) / dt or 0
                end
                prev.total, prev.busy = total, busy
            end

            local memTotal = tonumber(out:match("MemTotal:%s+(%d+)")) or 0
            local memAvail = tonumber(out:match("MemAvailable:%s+(%d+)")) or 0
            s.memTotal, s.memUsed = memTotal * 1024, (memTotal - memAvail) * 1024
            s.mem = memTotal > 0 and (memTotal - memAvail) / memTotal or 0

            local rx, tx = 0, 0
            for name, r, t in out:gmatch("\n%s*([%w%-%.]+):%s*(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)") do
                if name ~= "lo" then rx, tx = rx + tonumber(r), tx + tonumber(t) end
            end

            local rd, wr, ticks = 0, 0, 0
            if rootdisk and rootdisk ~= "" then
                local line = out:match("\n%s*%d+%s+%d+%s+" .. rootdisk:gsub("%p", "%%%0") .. "%s+([%d%s]+)")
                if line then
                    local f = {}
                    for n in line:gmatch("%d+") do f[#f + 1] = tonumber(n) end
                    rd, wr, ticks = (f[3] or 0) * 512, (f[7] or 0) * 512, f[10] or 0
                end
            end

            local clock = os.clock()
            if prev.clock then
                local dt = math.max(clock - prev.clock, 0.25)
                s.down, s.up = (rx - prev.rx) / dt, (tx - prev.tx) / dt
                s.read, s.write = (rd - prev.rd) / dt, (wr - prev.wr) / dt
                s.disk = math.min(1, (ticks - prev.ticks) / (dt * 1000))
            end
            prev.clock, prev.rx, prev.tx, prev.rd, prev.wr, prev.ticks = clock, rx, tx, rd, wr, ticks

            s.gpu, s.gpuMemUsed, s.gpuMemTotal, s.gpuTemp = gpu.util, gpu.memUsed, gpu.memTotal, gpu.temp

            if s.cpu then fact["m.cpu"] = s.cpu end
            fact["m.mem"] = s.mem
            fact["m.gpu"] = s.gpu
            if s.down then
                fact["m.down"] = math.min(1, s.down / NET_CEIL)
                fact["m.up"] = math.min(1, s.up / NET_CEIL)
                fact["m.disk"] = s.disk
            end
            M.last = s
            for _, fn in ipairs(M.listeners) do pcall(fn, s) end
        end)
    end

    local slow = 0
    every(500, function()
        slow = slow + 1
        if fact["meters.fast"] or M.watchers > 0 or slow >= 4 then
            slow = 0
            sample()
        end
    end)
    sample()
end
