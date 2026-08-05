pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness for every panel the kernel exposes a backlight for: the
// internal one directly, and external monitors through ddcci, which registers
// them as ordinary backlight devices so both are driven the same way.
//
// Levels are read from sysfs and set through logind, which authorises the
// write against the active session. Writing sysfs directly would need the
// files loosened by a udev rule; this needs nothing.
Singleton {
    id: root

    // One entry per device: name, current level and maximum, in the order the
    // kernel lists them. Rebuilt on rescan rather than bound, since the set
    // only changes when a monitor is plugged or unplugged.
    property var devices: []

    readonly property bool available: devices.length > 0

    // One level for the lot. The panels are set together, so the reported
    // level is just the first one's: averaging would drift the moment a
    // monitor's own buttons moved one of them independently, and there is only
    // one control to reflect it in anyway.
    readonly property real value: devices.length > 0 ? devices[0].value : 0

    // Device names are not stable: an external backlight is named after the
    // i2c bus it was bound on, and that numbering moves. Everything here goes
    // through the enumerated list rather than a hardcoded name.
    Process {
        id: scan

        // Emitted one device per line as "name max actual", so the parser does
        // not have to know the layout of sysfs.
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -e \"$d/max_brightness\" ] || continue; printf '%s %s %s\\n' \"${d##*/}\" \"$(cat $d/max_brightness)\" \"$(cat $d/actual_brightness)\"; done </dev/null"]

        stdout: StdioCollector {
            id: scanOut
        }

        onExited: (exitCode, exitStatus) => {
            // Killed part way through, or overtaken by a write that started
            // after this scan did: either way the reading is not the truth any
            // more and applying it would undo what was just set.
            if (exitCode !== 0 || settling.running || apply.running)
                return;

            const out = [];
            for (const line of scanOut.text.trim().split("\n")) {
                if (line === "")
                    continue;
                const f = line.split(/\s+/);
                if (f.length < 3)
                    continue;

                const max = Number(f[1]);
                if (!(max > 0))
                    continue;

                out.push({
                    name: f[0],
                    max: max,
                    value: Number(f[2]) / max
                });
            }
            root.devices = out;
        }
    }


    function rescan() {
        // A scan that overlaps a write reads a level that is on its way to
        // being replaced, and ddcci reports the old one for a moment after the
        // write lands. Either way the answer is stale, and applying it drags
        // the slider back to where it just came from.
        if (settling.running || apply.running)
            return;
        scan.running = true;
    }

    Component.onCompleted: rescan()

    // Levels drift when something else changes them: the brightness keys, the
    // monitor's own buttons, or a lid event. Polled only while a panel is
    // showing the sliders, the same way the meters are.
    property int watchers: 0

    function watch(on) {
        watchers = Math.max(0, watchers + (on ? 1 : -1));
    }

    // Held after a write for long enough that the panels have caught up. DDC
    // is the slow one: the internal panel reports back immediately, an
    // external monitor takes a moment.
    Timer {
        id: settling
        interval: 1200
    }

    Timer {
        running: root.watchers > 0
        interval: 2000
        repeat: true
        onTriggered: root.rescan()
    }

    // Applied through logind on the system bus: the user bus has no such
    // service, and the session is what authorises the write.
    //
    // Every panel is set in one call rather than one process per device, so
    // dragging does not spawn a pair of them per frame and the displays move
    // together instead of one trailing the other.
    Process {
        id: apply
    }

    function set(fraction) {
        if (devices.length === 0)
            return;

        const clamped = Math.max(0, Math.min(1, fraction));

        // Updated in place so the slider tracks the drag rather than waiting
        // for the next scan to catch up.
        const next = [];
        const calls = [];
        for (const d of devices) {
            const level = Math.round(clamped * d.max);
            next.push({
                name: d.name,
                max: d.max,
                value: level / d.max
            });
            calls.push("busctl --system call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight " + d.name + " " + level);
        }
        devices = next;

        // Restarting mid write drops the in flight call, which is what keeps a
        // drag from queueing every intermediate level behind a slow monitor:
        // DDC writes take long enough that the queue would outlive the drag.
        apply.running = false;
        apply.command = ["sh", "-c", "exec </dev/null; " + calls.join("; ")];
        apply.running = true;

        // A scan already in flight was started against the old level, so its
        // answer is worthless now: drop it rather than letting it land on top
        // of what was just set.
        scan.running = false;
        settling.restart();
    }
}
