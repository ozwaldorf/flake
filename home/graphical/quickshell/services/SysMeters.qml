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

    // The same readings in their own units, for anything that wants to say
    // what the percentage is of. Bytes throughout; the meters themselves only
    // ever need the percentage.
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real networkRate: 0

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
    property var networkHistory: []

    readonly property int historyLength: 60
    readonly property int historyInterval: 2000

    Timer {
        interval: root.historyInterval
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // In their own units where they have one, so a graph can be read
            // against the reading beside it rather than against a percentage
            // of something the axis does not name.
            root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            root.memoryHistory = root.push(root.memoryHistory, root.memoryUsed);
            root.networkHistory = root.push(root.networkHistory, root.networkRate);
        }
    }

    // Reassigned rather than mutated: a binding on the list does not re-evaluate
    // when its contents change, only when the property itself is set.
    function push(list, value) {
        const out = list.slice(list.length >= historyLength ? 1 : 0);
        out.push(value);
        return out;
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
    property int network: 0
    readonly property real netCeilingBits: 100 * 1000 * 1000
    readonly property real netCeiling: netCeilingBits / 8

    property var prevCpu: null
    property real prevNetBytes: 0

    // wall clock of the last network sample, so the rate is divided by the time
    // actually covered rather than the current interval, which changes on hover
    property real prevNetAt: 0

    FileView {
        id: stat
        path: "/proc/stat"
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
    }

    Timer {
        id: sampler

        interval: root.active ? root.intervalActive : root.intervalIdle
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            root.readCpu();
            root.readMemory();
            root.readNetwork();
        }
    }

    function readCpu() {
        stat.reload();

        const line = stat.text().split("\n").find(l => l.startsWith("cpu "));
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
                cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - dIdle / dTotal))));
        }

        prevCpu = {
            idle: idle,
            total: total
        };
    }

    function readMemory() {
        meminfo.reload();

        let total = 0;
        let available = 0;
        for (const line of meminfo.text().split("\n")) {
            if (line.startsWith("MemTotal:"))
                total = Number(line.split(/\s+/)[1]);
            else if (line.startsWith("MemAvailable:"))
                available = Number(line.split(/\s+/)[1]);
            if (total && available)
                break;
        }

        if (total > 0) {
            memory = Math.max(0, Math.min(100, Math.round(100 * (1 - available / total))));
            // kept in bytes so whatever displays them picks its own unit;
            // /proc/meminfo counts kibibytes
            memoryTotal = total * 1024;
            memoryUsed = (total - available) * 1024;
        }
    }

    function readNetwork() {
        netdev.reload();

        let bytes = 0;
        for (const line of netdev.text().split("\n").slice(2)) {
            const parts = line.trim().split(/\s+/);
            if (parts.length < 10)
                continue;
            // skip loopback, it is not real traffic
            if (parts[0].startsWith("lo:"))
                continue;
            bytes += Number(parts[1]) + Number(parts[9]);
        }

        const now = Date.now();

        if (prevNetBytes > 0 && prevNetAt > 0) {
            const elapsed = (now - prevNetAt) / 1000;
            if (elapsed > 0) {
                const rate = Math.max(0, (bytes - prevNetBytes) / elapsed);
                network = Math.max(0, Math.min(100, Math.round(100 * rate / netCeiling)));
                networkRate = rate;
            }
        }

        prevNetBytes = bytes;
        prevNetAt = now;
    }
}
