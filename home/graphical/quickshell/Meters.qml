pragma Singleton

import QtQuick
import Quickshell
import "services"

// What each system meter is, and how it reads: the rail draws them as marks
// and the tip draws them in full, both from the definitions here rather than
// each keeping its own list of colours and kinds.
Singleton {
    id: root

    // the outgoing half of a directional reading, distinct from the meter's
    // own colour but of a piece with it: peach against red and yellow alike
    readonly property color secondFill: Theme.peach

    readonly property var defs: ({
            network: {
                icon: Theme.iconNetwork,
                label: "Net",
                fill: Theme.red
            },
            cpu: {
                icon: Theme.iconCpu,
                label: "CPU",
                fill: Theme.mauve,
                // a percentage cannot pass a hundred, so the axis must not either
                limit: 100
            },
            gpu: {
                icon: Theme.iconGpu,
                label: "GPU",
                fill: Theme.blue,
                limit: 100
            },
            vram: {
                icon: Theme.iconGpu,
                label: "VRAM",
                fill: Theme.blue,
                dial: true
            },
            memory: {
                icon: Theme.iconMemory,
                label: "Memory",
                fill: Theme.green
            },
            disk: {
                icon: Theme.iconDisk,
                label: "Disk",
                fill: Theme.yellow,
                dial: true
            },
            io: {
                icon: Theme.iconDisk,
                label: "Disk I/O",
                fill: Theme.yellow
            },
            // what the machine is rather than what it is doing, which is read
            // once on the way past rather than watched
            summary: {
                icon: Theme.iconHost,
                label: "System",
                fill: Theme.overlay2
            }
        })

    // Without the driver there is no GPU reading to show, so those drop out
    // everywhere rather than sitting at zero.
    function available(kind) {
        return SysMeters.gpuAvailable || (kind !== "gpu" && kind !== "vram");
    }

    // ---- the rail ----

    // down the rail, in order
    readonly property var rail: ["network", "cpu", "gpu", "memory", "disk"].filter(available)

    // Percent filled, and the part stacked on it for a directional reading:
    // down from the base and up on top of it, so the mark says which way the
    // traffic is going rather than only that there is some.
    function level(kind) {
        if (kind === "network")
            return SysMeters.networkDown;
        if (kind === "cpu")
            return SysMeters.cpu;
        if (kind === "gpu")
            return SysMeters.gpu;
        if (kind === "memory")
            return SysMeters.memory;
        if (kind === "disk")
            return SysMeters.disk;
        return 0;
    }

    function secondLevel(kind) {
        return kind === "network" ? SysMeters.networkUp : 0;
    }

    function hasSecond(kind) {
        return kind === "network" || kind === "io";
    }

    // ---- the tip ----

    // Rows are numbered from the bottom, where the wide end sits against the
    // meters. Widths shape the wedge: each row is narrower than the one below
    // it, and the sizes vary within a row so the stack does not read as a
    // grid. Without the GPU the top row empties rather than leaving a gap,
    // since the pair sharing it are both the card's.
    readonly property var tip: [
        // row 0, against the meters: the widest
        {
            kind: "io",
            row: 0,
            width: 180
        },
        {
            kind: "disk",
            row: 0,
            width: 134
        },
        {
            kind: "memory",
            row: 0,
            width: 150
        },
        // row 1
        {
            kind: "network",
            row: 1,
            width: 220
        },
        {
            kind: "cpu",
            row: 1,
            width: 182
        },
        // row 2, the narrow end
        {
            kind: "vram",
            row: 2,
            width: 134
        },
        {
            kind: "gpu",
            row: 2,
            width: 176
        },
        // the apex
        {
            kind: "summary",
            row: 3,
            width: 225
        }
    ].filter(m => available(m.kind))

    // The window of past readings a chart draws, and the second series over it
    // for the two directional readings.
    function history(kind) {
        if (kind === "cpu")
            return SysMeters.cpuHistory;
        if (kind === "memory")
            return SysMeters.memoryHistory;
        if (kind === "gpu")
            return SysMeters.gpuHistory;
        if (kind === "io")
            return SysMeters.diskReadHistory;
        if (kind === "network")
            return SysMeters.networkDownHistory;
        return [];
    }

    function secondHistory(kind) {
        if (kind === "network")
            return SysMeters.networkUpHistory;
        if (kind === "io")
            return SysMeters.diskWriteHistory;
        return [];
    }

    // what a chart's axis tops out at
    function ceiling(kind) {
        return kind === "memory" ? SysMeters.memoryTotal : defs[kind].limit ?? Infinity;
    }

    // The two rates a directional reading carries, against one scale so the
    // pair is read as two parts of a figure rather than each in whatever unit
    // happens to suit it.
    function rates(kind) {
        return kind === "io" ? [SysMeters.diskReadRate, SysMeters.diskWriteRate] : [SysMeters.networkDownRate, SysMeters.networkUpRate];
    }

    function rateScale(kind) {
        const r = rates(kind);
        return SysMeters.byteScale(Math.max(r[0], r[1]));
    }

    // A dial's share: how much of a fixed whole is used.
    function used(kind) {
        return kind === "vram" ? SysMeters.gpuMemoryUsed : SysMeters.diskUsed;
    }

    function total(kind) {
        return kind === "vram" ? SysMeters.gpuMemoryTotal : SysMeters.diskTotal;
    }

    function share(kind) {
        const t = total(kind);
        return t > 0 ? used(kind) / t : 0;
    }

    // The reading beside the header.
    function detail(kind) {
        if (kind === "cpu")
            return SysMeters.cpuTemperature > 0 ? SysMeters.cpu + "% Load \u00b7 " + SysMeters.fahrenheit(SysMeters.cpuTemperature) + "\u00b0F" : SysMeters.cpu + "% Load";
        if (kind === "memory")
            return SysMeters.formatBytes(SysMeters.memoryUsed) + " / " + SysMeters.formatBytes(SysMeters.memoryTotal);
        if (kind === "gpu")
            return SysMeters.gpu + "% Load \u00b7 " + SysMeters.fahrenheit(SysMeters.gpuTemperature) + "\u00b0F";
        // What is left rather than what is taken: the ring already says what
        // share is gone, and the figure worth reading beside it is the
        // headroom.
        if (defs[kind].dial)
            return SysMeters.formatBytes(total(kind) - used(kind)) + " free";
        return "\u2193 " + SysMeters.formatBytesAt(rates(kind)[0], rateScale(kind)) + "/s";
    }

    function secondDetail(kind) {
        return hasSecond(kind) ? "\u2191 " + SysMeters.formatBytesAt(rates(kind)[1], rateScale(kind)) + "/s" : "";
    }

    // How a chart labels its axis.
    function format(kind) {
        if (kind === "cpu" || kind === "gpu")
            return v => Math.round(v) + "%";
        if (kind === "memory")
            return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top));
        return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top)) + "/s";
    }
}
