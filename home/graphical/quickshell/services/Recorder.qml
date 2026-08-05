pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording: pick a region, record it, and stop by asking again.
//
// Two processes in sequence. slurp draws the selection and prints a geometry,
// exiting non zero if it is cancelled; wf-recorder then runs until it is asked
// to stop. Nothing here polls.
Singleton {
    id: root

    // true from the moment wf-recorder starts until it has written the file
    readonly property bool recording: recorder.running

    // Tracked rather than bound to slurp.running: a process that fails to
    // start never enters the running state and never emits exited, so a
    // binding would either never light up or, worse, latch on with nothing
    // left to turn it off.
    property bool selecting: false

    readonly property bool busy: recording || selecting

    // Seconds elapsed, for the widget to display. Counted from a start stamp
    // rather than incremented, so a late or dropped tick cannot make the
    // reported duration drift from the file's own.
    property real startedAt: 0
    property int elapsed: 0

    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60);
        const s = elapsed % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // path of the file being written, and of the last one finished
    property string path: ""
    property string lastPath: ""

    // set when something goes wrong, cleared on the next attempt
    property string error: ""

    signal finished(string file)

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    function toggle() {
        if (recording)
            stop();
        else if (!selecting)
            start();
    }

    function start() {
        error = "";
        selecting = true;
        slurp.running = true;
        // running is still false here: the process starts asynchronously, so
        // a failure is caught by the watchdog below rather than inline.
        selectGuard.restart();
    }

    // A binary that cannot be found fails without ever running, and quickshell
    // reports that as a warning with no exited signal, so nothing would clear
    // the waiting state. Anything that has not started shortly after being
    // asked to never will.
    Timer {
        id: selectGuard

        interval: 2000
        onTriggered: {
            if (root.selecting && !slurp.running) {
                root.selecting = false;
                root.error = "Could not start slurp";
            }
        }
    }

    // SIGINT rather than kill: wf-recorder traps it to flush the encoder and
    // close the container. Killing it outright leaves an unplayable file.
    function stop() {
        if (recorder.running)
            recorder.signal(2);
    }

    // Region selection. Cancelling with escape exits non zero and prints
    // nothing, which is the difference between "no region" and "no recording".
    Process {
        id: slurp

        // slurp reads stdin for a list of predefined regions, so an open pipe
        // that is never written to leaves it blocked on that read instead of
        // ever drawing the selection. stdinEnabled only governs whether the
        // shell may write to the pipe; the child is handed one either way, so
        // stdin has to be redirected for slurp to see an end of file and take
        // its region from the pointer.
        command: ["sh", "-c", "exec slurp </dev/null"]

        stdout: StdioCollector {
            id: region
        }

        onExited: (exitCode, exitStatus) => {
            root.selecting = false;

            // Escape prints nothing and exits non zero, which is a cancel and
            // not a failure worth reporting.
            const geometry = region.text.trim();
            if (exitCode !== 0 || geometry === "")
                return;

            root.begin(geometry);
        }

        // Covers the binary being missing or unexecutable, where exited never
        // fires because the process never started.
        onStarted: root.selecting = true
    }

    function begin(geometry) {
        // Local time rather than ISO: the name is read by a person browsing a
        // directory, and colons are awkward in a filename besides.
        const now = new Date();
        const stamp = now.getFullYear() + pad(now.getMonth() + 1) + pad(now.getDate()) + "-" + pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds());

        path = videos + "/screen-recording-" + stamp + ".mp4";
        startedAt = Date.now();
        elapsed = 0;

        recorder.command = ["wf-recorder", "-c", "libx264", "-g", geometry, "-f", path];
        recorder.running = true;
        recordGuard.restart();
    }

    // same failure to start as slurp, caught the same way
    Timer {
        id: recordGuard

        interval: 2000
        onTriggered: {
            if (root.path !== "" && !recorder.running) {
                root.path = "";
                root.error = "Could not start wf-recorder";
            }
        }
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    readonly property string videos: (Quickshell.env("XDG_VIDEOS_DIR") || Quickshell.env("HOME") + "/Videos")

    Process {
        id: recorder

        // nothing is ever written to it, and a recorder has no use for one
        stdinEnabled: false

        stderr: StdioCollector {
            id: recorderError
        }

        onExited: (exitCode, exitStatus) => {
            // Stopping with SIGINT is the normal path and is not a failure,
            // however the exit is reported.
            const wrote = root.path;
            root.path = "";
            root.elapsed = 0;

            if (exitCode !== 0 && exitCode !== 130 && exitStatus !== 0) {
                root.error = recorderError.text.trim().split("\n").pop() || "Recording failed";
                return;
            }

            root.lastPath = wrote;
            root.finished(wrote);
        }
    }
}
