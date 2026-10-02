pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording, owned by hyprcapture's compositor plugin.
//
// The plugin does the capturing; this only asks it to start or stop and reads
// back what it reports. Starting opens hyprcapture's own overlay to choose a
// format and a target, so there is a gap between the click and the recording
// actually beginning. Stopping is immediate.
Singleton {
    id: root

    // Mirrors of the plugin's state, refreshed from the status socket.
    property bool recording: false
    property int elapsed: 0
    property string path: ""
    property string lastPath: ""

    // True while the encoder drains after a stop. The file is not finished yet,
    // so the tile keeps showing something is happening.
    property bool finalizing: false

    // True between asking for the overlay and the plugin reporting a recording.
    // Not derived from the socket: the overlay is open in this window and the
    // plugin still reports inactive, which is indistinguishable from idle.
    property bool selecting: false

    readonly property bool busy: recording || selecting || finalizing

    property string error: ""

    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    signal finished(string file)

    // The plugin serves one newline terminated JSON object per connection and
    // then closes, so state has to be pulled rather than subscribed to. Polled
    // quickly while something is happening and slowly when idle, where the only
    // thing being waited for is a recording started from hyprcapture's own
    // keybind rather than from the tile.
    Timer {
        interval: root.busy ? 500 : 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // XDG_RUNTIME_DIR is the plugin's primary location; it falls back to
    // /dev/shm and then /tmp when that is unavailable, so try them in the same
    // order and stay on whichever answers. The uid is the runtime directory's
    // own name, which is the only place the shell can read it without asking.
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") ?? ""
    readonly property string uid: runtimeDir.split("/").pop()
    readonly property var socketPaths: [`${runtimeDir}/hyprcapture/recording.sock`, `/dev/shm/hyprcapture-${uid}/recording.sock`, `/tmp/hyprcapture-${uid}/recording.sock`]

    // which of those is being tried, how many have failed this poll, and
    // whether this poll got through to one at all
    property int pathIndex: 0
    property int misses: 0
    property bool reached: false

    function poll() {
        if (status.connected)
            return;
        misses = 0;
        reached = false;
        status.connected = true;
    }

    Socket {
        id: status

        path: root.socketPaths[root.pathIndex]

        parser: SplitParser {
            onRead: line => {
                try {
                    const state = JSON.parse(line);
                    root.apply(state.phase === "recording", state.phase === "finalizing", Math.floor(state.elapsed || 0), state.output || "");
                } catch (e) {
                    // A malformed line is a transient read, not a state change.
                }

                // Hung up from this side once the reading is in, rather than
                // left for the plugin to close, which reports as an error.
                Qt.callLater(() => status.connected = false);
            }
        }

        onConnectedChanged: {
            if (connected)
                root.reached = true;
        }

        // Nothing listening there: move on to the next location. With none
        // answering the plugin is not loaded, and a recording cannot be
        // running either. An error after connecting is only the hang up.
        onError: {
            if (root.reached)
                return;
            root.misses++;
            if (root.misses >= root.socketPaths.length) {
                root.apply(false, false, 0, "");
                return;
            }
            root.pathIndex = (root.pathIndex + 1) % root.socketPaths.length;
            Qt.callLater(() => status.connected = true);
        }
    }

    // Folds one status reading into the properties, and turns the edge where a
    // recording stops into the finished signal.
    function apply(isRecording, isFinalizing, seconds, output) {
        // The overlay has served its purpose once the plugin reports a
        // recording; a cancelled overlay is caught by the guard below.
        if (isRecording)
            selecting = false;

        // Remember the path while it is still being reported: it is cleared
        // from the status once finalization completes.
        if (output !== "")
            path = output;

        if (recording && !isRecording && !isFinalizing)
            complete();
        if (finalizing && !isFinalizing && !isRecording)
            complete();

        recording = isRecording;
        finalizing = isFinalizing;
        elapsed = seconds;
    }

    function complete() {
        if (path === "")
            return;
        lastPath = path;
        path = "";
        finished(lastPath);
    }

    function toggle() {
        if (recording || finalizing)
            stop();
        else if (!selecting)
            start();
    }

    // Opens hyprcapture's overlay. The recording only begins once a format and
    // a target have been chosen there, which is why this does not set
    // recording directly.
    function start() {
        error = "";
        selecting = true;
        dispatch.command = ["hyprctl", "eval", "hl.plugin.hyprcapture.record_toggle()"];
        dispatch.running = true;
        selectGuard.restart();
    }

    function stop() {
        dispatch.command = ["hyprctl", "eval", "hl.plugin.hyprcapture.record_stop()"];
        dispatch.running = true;
    }

    // The overlay can be dismissed with escape, which the plugin does not
    // report: it looks exactly like never having started. Give up waiting after
    // long enough that a deliberate selection has been made.
    Timer {
        id: selectGuard

        interval: 60000
        onTriggered: root.selecting = false
    }

    Process {
        id: dispatch

        stdinEnabled: false

        // hyprctl writes both its own connection failures and the plugin's
        // errors here rather than to stderr, so there is nothing to collect
        // from the latter.
        stdout: StdioCollector {
            id: dispatchOut
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.error = "";
                return;
            }

            const reply = dispatchOut.text.trim().split("\n").pop().replace(/^error:\s*/, "");

            // Stopping something that has already ended is the normal way a
            // recording with its own duration limit finishes: the plugin has
            // cleared it before the tile asked. Nothing failed, so the status
            // socket stays the authority on what happened to the file.
            if (reply === "no active recording") {
                root.error = "";
                return;
            }

            root.selecting = false;
            root.error = reply || "Could not reach hyprland";
        }
    }
}
