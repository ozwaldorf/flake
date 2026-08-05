pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Screen recording toggle. Starting asks for a region first, so the tile sits
// in a waiting state between the click and the recording actually beginning.
ToggleTile {
    id: root

    label: "Screen record"
    hasList: false

    // The puck is lit for the whole operation, selection included: the click
    // has been taken and something is happening.
    on: Recorder.busy

    status: {
        if (Recorder.error !== "")
            return Recorder.error;
        if (Recorder.selecting)
            return "Select a region";
        if (Recorder.recording)
            return "Recording " + Recorder.elapsedText;
        if (Recorder.lastPath !== "")
            return "Saved " + Recorder.lastPath.split("/").pop();
        return "Idle";
    }

    warn: Recorder.error !== ""

    onToggled: Recorder.toggle()

    // Red while recording rather than the usual blue, and only then: during
    // selection nothing is being captured yet.
    puckFill: Recorder.recording ? Theme.red : Recorder.selecting ? Theme.surface2 : Theme.surface1

    glyph: RecordGlyph {
        anchors.centerIn: parent
        recording: Recorder.recording
        fill: Recorder.recording ? Theme.crust : Theme.overlay1
    }
}
