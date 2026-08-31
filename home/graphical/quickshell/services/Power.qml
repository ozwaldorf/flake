pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Session power actions, handed to systemd.
//
// Nothing here has state worth mirroring: an action either takes the session
// down or it does not, and the shell goes with it either way. The one thing
// worth reporting is a refusal, since a polkit denial otherwise looks like the
// click was never taken.
Singleton {
    id: root

    // Set when systemd turned an action down; cleared as soon as another is
    // asked for. Not per action: only one is ever in flight.
    property string error: ""

    // What was asked for while it is still pending, so the tile can say which
    // one it is waiting on. Usually a blink, but a polkit prompt holds here.
    property string pending: ""

    readonly property var actions: [
        {
            key: "suspend",
            label: "Suspend",
            verb: "suspend"
        },
        {
            key: "restart",
            label: "Restart",
            verb: "reboot"
        },
        {
            key: "shutdown",
            label: "Shut down",
            verb: "poweroff"
        }
    ]

    function run(key) {
        if (pending !== "")
            return;

        for (const action of actions) {
            if (action.key !== key)
                continue;

            error = "";
            pending = key;
            dispatch.command = ["systemctl", action.verb];
            dispatch.running = true;
            return;
        }
    }

    function label(key) {
        for (const action of actions) {
            if (action.key === key)
                return action.label;
        }
        return "";
    }

    Process {
        id: dispatch

        stdinEnabled: false

        stderr: StdioCollector {
            id: dispatchErr
        }

        onExited: exitCode => {
            const asked = root.pending;
            root.pending = "";

            // A suspend returns once the machine is back, which is a success
            // arriving long after the panel closed. Nothing to report either
            // way; only a refusal is worth surfacing.
            if (exitCode === 0)
                return;

            root.error = dispatchErr.text.trim().split("\n").pop() || ("Could not " + root.label(asked).toLowerCase());
        }
    }
}
