pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording through gpu-screen-recorder.
//
// Starting asks slurp for a region, or a whole output when one is clicked, so
// there is a gap between the click and the recording actually beginning.
// Stopping interrupts the recorder, which then finishes writing the file.
Singleton {
    id: root

    property bool recording: false
    property int elapsed: 0
    property string path: ""
    property string lastPath: ""

    // True while the encoder drains after a stop. The file is not finished yet,
    // so the tile keeps showing something is happening.
    property bool finalizing: false

    // True while slurp is waiting for a selection
    property bool selecting: false

    readonly property bool busy: recording || selecting || finalizing

    property string error: ""

    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string saveDir: Quickshell.env("XDG_VIDEOS_DIR") ?? `${Quickshell.env("HOME")}/Videos`

    signal finished(string file)

    function toggle() {
        if (recording)
            stop();
        else if (!selecting && !finalizing)
            start();
    }

    function start() {
        error = "";
        selecting = true;
        select.running = true;
    }

    function stop() {
        recording = false;
        finalizing = true;
        recorder.signal(2);
    }

    Process {
        id: select

        command: ["slurp", "-o", "-f", "%wx%h+%x+%y"]

        stdout: StdioCollector {
            id: selection
        }

        // a non-zero exit is the selection being cancelled
        onExited: exitCode => {
            root.selecting = false;
            const region = selection.text.trim();
            if (exitCode !== 0 || region === "")
                return;
            root.path = `${root.saveDir}/screen-recording-${Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")}.mp4`;
            recorder.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && exec gpu-screen-recorder -w region -region "$1" -f 60 -cursor yes -o "$2"', "sh", region, root.path];
            recorder.running = true;
        }
    }

    Process {
        id: recorder

        stdinEnabled: false

        stderr: StdioCollector {
            id: recorderErr
        }

        onStarted: {
            root.elapsed = 0;
            root.recording = true;
        }

        onExited: exitCode => {
            const wasStopped = root.finalizing;
            root.recording = false;
            root.finalizing = false;
            if (exitCode === 0 || wasStopped) {
                root.lastPath = root.path;
                root.finished(root.lastPath);
            } else {
                root.error = recorderErr.text.trim().split("\n").pop() || "Recording failed";
            }
            root.path = "";
        }
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.elapsed++
    }
}
