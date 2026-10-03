pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and network load, all read from /proc on one timer. The only
// polled source in the shell; everything else is event driven.
Singleton {
    id: root

    // percent busy, 0-100
    property int cpu: 0
    property int memory: 0
    property int disk: 0

    // The same readings in their own units, for anything that wants to say
    // what the percentage is of. Bytes throughout; the meters themselves only
    // ever need the percentage.
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real networkDownRate: 0
    property real networkUpRate: 0
    property real diskUsed: 0
    property real diskTotal: 0

    // ---- history ----
    //
    // A window of past readings for the tooltips to draw. Recorded on its own
    // timer rather than alongside the sampling, which speeds up while a rail is
    // out: a buffer filled at two different rates would put an inconsistent
    // time axis under the graph.
    //
    // Oldest first, so a graph reads left to right.
    property var cpuHistory: []
    property var memoryHistory: []
    property var networkDownHistory: []
    property var networkUpHistory: []
    property var diskReadHistory: []
    property var diskWriteHistory: []
    property var gpuHistory: []

    readonly property int historyLength: 60
    readonly property int historyInterval: 2000

    // How many of the samples at the head of the buffers were taken in the
    // first second after the shell started. Those catch every counter mid
    // settle, a rate measured against nothing or a load caught during the
    // shell's own startup, so a chart leaves them out of its range; the
    // count falls back to nothing as they roll out of the window.
    property int warmup: 0
    readonly property real startedAt: Date.now()

    Timer {
        interval: root.historyInterval
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (Date.now() - root.startedAt < 1000)
                root.warmup++;
            else if (root.warmup > 0 && root.cpuHistory.length >= root.historyLength)
                root.warmup--;

            // In their own units where they have one, so a graph can be read
            // against the reading beside it rather than against a percentage
            // of something the axis does not name.
            root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            root.memoryHistory = root.push(root.memoryHistory, root.memoryUsed);
            root.networkDownHistory = root.push(root.networkDownHistory, root.networkDownRate);
            root.networkUpHistory = root.push(root.networkUpHistory, root.networkUpRate);
            root.diskReadHistory = root.push(root.diskReadHistory, root.diskReadRate);
            root.diskWriteHistory = root.push(root.diskWriteHistory, root.diskWriteRate);
            root.gpuHistory = root.push(root.gpuHistory, root.gpu);
        }
    }

    // Reassigned rather than mutated: a binding on the list does not re-evaluate
    // when its contents change, only when the property itself is set.
    function push(list, value) {
        const out = list.slice(list.length >= historyLength ? 1 : 0);
        out.push(value);
        return out;
    }

    // a fraction as a whole percentage, held to 0-100
    function percent(fraction) {
        return Math.max(0, Math.min(100, Math.round(100 * fraction)));
    }

    // ---- disk ----
    //
    // Root only. The other mounts are a boot partition and whatever removable
    // media happens to be in, and neither is a reading you keep an eye on.
    //
    // On its own timer at a minute: free space moves on the scale of installs
    // and builds, not of the sample window the other meters are read over, and
    // it is a syscall against the filesystem rather than a line out of /proc.
    // Not held in a history buffer either, since the tip draws it as a dial
    // rather than a line and nothing would read the window back.
    //
    // Available rather than free: the difference is the reserve only root can
    // write into, and counting it as usable disagrees with what df reports and
    // with what actually runs out.
    readonly property int diskInterval: 60000

    // Which filesystem the reading is of, so whatever displays it can say so
    // rather than repeating the path and drifting from what is measured.
    readonly property string diskMount: "/"

    Process {
        id: diskScan

        // Blocks and their size, so the parser does no unit arithmetic of its
        // own: total, available, block size.
        command: ["stat", "-f", "-c", "%b %a %S", root.diskMount]

        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/).map(Number);
                if (f.length < 3 || !(f[0] > 0) || !(f[2] > 0))
                    return;

                root.diskTotal = f[0] * f[2];
                root.diskUsed = (f[0] - f[1]) * f[2];
                root.disk = root.percent(root.diskUsed / root.diskTotal);
            }
        }
    }

    Timer {
        interval: root.diskInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: diskScan.running = true
    }

    // ---- system identity ----
    //
    // Who and what this machine is. All of it fixed for the life of the
    // session except the uptime, so it is read once at startup rather than
    // polled, and only the clock below keeps counting.
    property string userName: ""
    property string hostName: ""
    property string osName: ""
    property string kernel: ""

    Process {
        id: identityScan

        running: true

        // One field per line, in the order they are read back. PRETTY_NAME
        // carries the release rather than only the distribution's name, and is
        // unquoted here so the parser does not have to.
        command: ["sh", "-c", "id -un; hostname; . /etc/os-release; echo \"$PRETTY_NAME\"; uname -r"]

        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n");
                if (f.length < 4)
                    return;

                root.userName = f[0];
                root.hostName = f[1];
                root.osName = f[2];
                root.kernel = f[3];
            }
        }
    }

    // The rest of what the drawer lists about the machine: the hardware, the
    // shell and compositor it is running, and which
    // generation of the system that is. Read at startup and again whenever
    // the drawer asks, since a switch moves the generation under a running
    // session. Read as key=value lines so a field that comes up empty does
    // not shift the rest.
    property string hostModel: ""
    property string cpuModel: ""
    property string gpuModel: ""
    property string shellRelease: ""
    property string wmRelease: ""

    // the system profile's generation, and when it was built, in epoch seconds
    property int generation: 0
    property real generationTime: 0

    // NixOS's own version string, which carries the nixpkgs date and revision
    property string nixosVersion: ""

    function rescanHost() {
        hostScan.running = true;
    }

    Process {
        id: hostScan

        running: true

        command: ["sh", "-c", ["d=/sys/devices/virtual/dmi/id", "echo \"model=$(cat $d/sys_vendor 2>/dev/null) $(cat $d/product_name 2>/dev/null)\"", "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//') ($(nproc))\"", "echo \"gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)\"", "echo \"shell=$(quickshell --version 2>/dev/null | head -1 | cut -d' ' -f1,2)\"", "echo \"wm=$(niri --version 2>/dev/null | cut -d' ' -f1,2)\"", "g=$(readlink /nix/var/nix/profiles/system)", "echo \"generation=$(echo $g | tr -dc 0-9) $(stat -c %Y /nix/var/nix/profiles/$g)\"", "echo \"nixos=$(nixos-version 2>/dev/null)\""].join("; ")]

        stdout: StdioCollector {
            onStreamFinished: {
                const keys = {
                    model: "hostModel",
                    cpu: "cpuModel",
                    gpu: "gpuModel",
                    shell: "shellRelease",
                    wm: "wmRelease",
                    nixos: "nixosVersion"
                };
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    const key = line.slice(0, i);
                    const value = line.slice(i + 1).trim();
                    if (key === "generation") {
                        const [number, time] = value.split(" ").map(Number);
                        root.generation = number || 0;
                        root.generationTime = time || 0;
                    } else if (keys[key]) {
                        root[keys[key]] = value;
                    }
                }
            }
        }
    }

    // Seconds since boot. Its own slow timer: it is read to the minute, so a
    // faster one would redraw the same string over and over.
    property real uptime: 0

    FileView {
        id: uptimeFile

        path: "/proc/uptime"

        onLoaded: {
            const v = Number(text().trim().split(/\s+/)[0]);
            if (v > 0)
                root.uptime = v;
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: uptimeFile.reload()
    }

    // Coarse by design: days and hours once it is past a day, hours and
    // minutes below that. A machine up for three weeks does not need its
    // seconds counted.
    function formatUptime(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);

        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    // ---- cpu temperature ----
    //
    // The package sensor from coretemp, in degrees. Read on the same timer as
    // the load it belongs beside.
    //
    // Found by name rather than by hwmon number, which is assigned in probe
    // order and moves between boots: the path is resolved once at startup and
    // read directly from then on.
    property int cpuTemperature: 0
    property string cpuTempPath: ""

    Process {
        id: cpuTempScan

        running: true

        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = coretemp ] && { echo $h/temp1_input; break; }; done"]

        stdout: StdioCollector {
            onStreamFinished: root.cpuTempPath = text.trim()
        }
    }

    FileView {
        id: cpuTemp

        path: root.cpuTempPath

        // millidegrees, as everything under hwmon reports
        onLoaded: {
            const v = Number(text().trim());
            if (v > 0)
                root.cpuTemperature = Math.round(v / 1000);
        }
    }

    // ---- disk io ----
    //
    // Read and write rates for the device the root filesystem sits on, from
    // /proc/diskstats. Cumulative sector counts, so like the network these are
    // deltas over the sample window and cannot be event driven.
    //
    // The whole disk rather than the partition or the mapper above it: a
    // stacked setup counts the same write at every layer, and the physical
    // device is the one that is actually busy.
    property real diskReadRate: 0
    property real diskWriteRate: 0

    // Which device that is, resolved at startup by walking the root
    // filesystem's stack down through LUKS to the disk underneath. Hardcoding
    // it would break on any machine but this one, and on this one after a
    // reinstall.
    property string diskDevice: ""

    Process {
        id: diskDeviceScan

        running: true

        // lsblk -s walks the stack downward; the disk is the bottom of it.
        // The tree drawing characters lsblk prefixes are stripped here rather
        // than parsed out later.
        command: ["sh", "-c", "lsblk -nso NAME,TYPE \"$(findmnt -no SOURCE /)\" | awk '$2==\"disk\"{gsub(/[^a-zA-Z0-9]/,\"\",$1); print $1; exit}'"]

        stdout: StdioCollector {
            onStreamFinished: root.diskDevice = text.trim()
        }
    }

    FileView {
        id: diskstats

        path: "/proc/diskstats"
        onLoaded: root.readDiskIo(text())
    }

    // Sectors are always 512 bytes in diskstats, whatever the drive's own
    // logical block size is.
    readonly property int sectorSize: 512

    property real prevDiskRead: 0
    property real prevDiskWrite: 0
    property real prevDiskAt: 0

    function readDiskIo(text) {
        const line = text.split("\n").find(l => l.trim().split(/\s+/)[2] === diskDevice);
        if (!line)
            return;

        const f = line.trim().split(/\s+/);
        if (f.length < 10)
            return;

        // fields 6 and 10: sectors read and sectors written
        const read = Number(f[5]) * sectorSize;
        const written = Number(f[9]) * sectorSize;
        const now = Date.now();

        if (prevDiskAt > 0) {
            const elapsed = (now - prevDiskAt) / 1000;
            if (elapsed > 0) {
                diskReadRate = Math.max(0, (read - prevDiskRead) / elapsed);
                diskWriteRate = Math.max(0, (written - prevDiskWrite) / elapsed);
            }
        }

        prevDiskRead = read;
        prevDiskWrite = written;
        prevDiskAt = now;
    }

    // ---- gpu ----
    //
    // Utilisation, video memory and temperature, out of one long running
    // nvidia-smi query that reports on its own interval rather than a process
    // spawned per sample. Two seconds matches the history interval, which is
    // the only thing that reads the utilisation back.
    //
    // The card here drives the displays and is not runtime suspended, so
    // polling it does not hold anything awake that would otherwise sleep.
    property int gpu: 0
    property real gpuMemoryUsed: 0
    property real gpuMemoryTotal: 0
    property int gpuTemperature: 0

    // Set once a reading has actually come back, so a machine without the
    // driver shows nothing rather than a meter pinned at zero.
    property bool gpuAvailable: false

    readonly property int gpuInterval: 2000

    Process {
        id: gpuScan

        running: true

        // One line per sample, comma separated, in the order asked for.
        // Megabytes for the memory figures, which is what the tool reports in.
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits", "-lms", String(root.gpuInterval)]

        stdout: SplitParser {
            onRead: line => {
                const f = line.split(",").map(s => Number(s.trim()));
                if (f.length < 4 || !(f[2] > 0) || f.some(isNaN))
                    return;

                root.gpu = root.percent(f[0] / 100);
                root.gpuMemoryUsed = f[1] * 1024 * 1024;
                root.gpuMemoryTotal = f[2] * 1024 * 1024;
                root.gpuTemperature = Math.round(f[3]);
                root.gpuAvailable = true;
            }
        }

        // Without the driver the first run fails and is left at that. A query
        // that had been answering is restarted, since that is the driver being
        // reloaded rather than missing.
        onExited: {
            if (root.gpuAvailable)
                gpuRestart.restart();
        }
    }

    Timer {
        id: gpuRestart

        interval: 5000
        onTriggered: gpuScan.running = true
    }

    // Byte counts in the largest unit that leaves a number worth reading, and
    // to one decimal only below a thousand: "2.5 GB" says as much as "2.54 GB"
    // in a tooltip and changes less often.
    readonly property var byteUnits: ["B", "KB", "MB", "GB", "TB"]

    // largest unit that leaves a number at or above one
    function byteScale(bytes) {
        let i = 0;
        let n = Math.max(0, bytes);
        while (n >= 1024 && i < byteUnits.length - 1) {
            n /= 1024;
            i++;
        }
        return i;
    }

    function formatBytes(bytes) {
        return formatBytesAt(bytes, byteScale(bytes));
    }

    // Sensors report celsius; the readings are kept in it and converted only
    // where they are drawn.
    function fahrenheit(celsius) {
        return Math.round(celsius * 9 / 5 + 32);
    }

    // Formatted against a given scale rather than each value picking its own,
    // so an axis reads in one unit down its whole length instead of switching
    // partway and inviting the two ends to be compared as if they matched.
    function formatBytesAt(bytes, scale) {
        const n = Math.max(0, bytes) / Math.pow(1024, scale);
        return (scale === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + byteUnits[scale];
    }

    // Sampled faster while a rail is out, since that is when the meters are
    // actually readable. These are deltas over the sample window, so nothing
    // here can be event driven: /proc carries cumulative counters, and a rate
    // only exists between two reads.
    //
    // Counted rather than a flag: there is one bar per monitor, and collapsing
    // one must not slow sampling while another is still expanded.
    property int watchers: 0
    readonly property bool active: watchers > 0

    function watch(on) {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }

    // Set by the shell rather than read from Theme: a service reaching back up
    // into the config root would make services and the root import each other.
    property int intervalActive: 500
    property int intervalIdle: 2000

    // Scaled against a fixed ceiling so the bar is absolute rather than
    // relative to whatever the busiest moment happened to be. Expressed in
    // bits to match how link rates are quoted; /proc reports bytes.
    property int networkDown: 0
    property int networkUp: 0
    readonly property real netCeilingBits: 100 * 1000 * 1000
    readonly property real netCeiling: netCeilingBits / 8

    property var prevCpu: null
    property real prevNetDown: 0
    property real prevNetUp: 0

    // wall clock of the last network sample, so the rate is divided by the time
    // actually covered rather than the current interval, which changes on hover
    property real prevNetAt: 0

    // Each parsed once its reload has landed rather than straight after asking
    // for it: a reload is scheduled, not performed, so text() on the next line
    // returns the previous sample, stamped with the wrong time besides.
    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: root.readCpu(text())
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: root.readMemory(text())
    }

    FileView {
        id: netdev

        path: "/proc/net/dev"
        onLoaded: root.readNetwork(text())
    }

    Timer {
        id: sampler

        interval: root.active ? root.intervalActive : root.intervalIdle
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            stat.reload();
            meminfo.reload();
            netdev.reload();
            if (root.diskDevice !== "")
                diskstats.reload();
            if (root.cpuTempPath !== "")
                cpuTemp.reload();
        }
    }

    function readCpu(text) {
        const line = text.split("\n").find(l => l.startsWith("cpu "));
        if (!line)
            return;

        const f = line.split(/\s+/).slice(1).map(Number);
        if (f.length < 5)
            return;

        const idle = f[3] + (f[4] || 0);
        const total = f.reduce((a, b) => a + b, 0);

        if (prevCpu) {
            const dTotal = total - prevCpu.total;
            const dIdle = idle - prevCpu.idle;
            if (dTotal > 0)
                cpu = percent(1 - dIdle / dTotal);
        }

        prevCpu = {
            idle: idle,
            total: total
        };
    }

    function readMemory(text) {
        let total = 0;
        let available = 0;
        for (const line of text.split("\n")) {
            if (line.startsWith("MemTotal:"))
                total = Number(line.split(/\s+/)[1]);
            else if (line.startsWith("MemAvailable:"))
                available = Number(line.split(/\s+/)[1]);
            if (total && available)
                break;
        }

        if (total > 0) {
            memory = percent(1 - available / total);
            // kept in bytes so whatever displays them picks its own unit;
            // /proc/meminfo counts kibibytes
            memoryTotal = total * 1024;
            memoryUsed = (total - available) * 1024;
        }
    }

    function readNetwork(text) {
        // Received and transmitted counted apart: summed, a saturated upload
        // and a saturated download read identically, which is the one thing
        // the meter is there to tell apart.
        let down = 0;
        let up = 0;
        for (const line of text.split("\n").slice(2)) {
            const parts = line.trim().split(/\s+/);
            if (parts.length < 10)
                continue;
            // skip loopback, it is not real traffic
            if (parts[0].startsWith("lo:"))
                continue;
            down += Number(parts[1]);
            up += Number(parts[9]);
        }

        const now = Date.now();

        if (prevNetAt > 0) {
            const elapsed = (now - prevNetAt) / 1000;
            if (elapsed > 0) {
                networkDownRate = Math.max(0, (down - prevNetDown) / elapsed);
                networkUpRate = Math.max(0, (up - prevNetUp) / elapsed);

                // Both against the same ceiling, so the two parts of the mark
                // are read on one scale rather than each being a share of a
                // total that moves.
                networkDown = percent(networkDownRate / netCeiling);
                networkUp = percent(networkUpRate / netCeiling);
            }
        }

        prevNetDown = down;
        prevNetUp = up;
        prevNetAt = now;
    }
}
