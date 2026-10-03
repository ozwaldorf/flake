pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Volume and microphone side by side over one shared device list.
//
// Volume takes two thirds: it carries the longer device name and is the one
// actually dragged, where the microphone is mostly muted and left alone.
TileGroup {
    id: root

    readonly property real unit: Theme.third(width)

    maxListHeight: 150

    VolumeSlider {
        width: root.unit * 2 + root.tileRow.spacing
        host: root.host
        device: "speaker"
        label: "Volume"
        listName: "speaker"
        expanded: root.open === "speaker"

        value: Audio.sink?.audio?.volume ?? 0
        muted: Audio.sink?.audio?.muted ?? false

        onMoved: v => Audio.setVolume(Audio.sink, v)
        onMuteToggled: Audio.toggleMuted(Audio.sink)
        onListToggled: root.toggle("speaker")
    }

    VolumeSlider {
        width: root.unit
        host: root.host
        device: "mic"
        label: "Mic"
        listName: "mic"
        expanded: root.open === "mic"

        value: Audio.source?.audio?.volume ?? 0
        muted: Audio.source?.audio?.muted ?? false

        onMoved: v => Audio.setVolume(Audio.source, v)
        onMuteToggled: Audio.toggleMuted(Audio.source)
        onListToggled: root.toggle("mic")
    }

    lists: [
        AudioList {
            objectName: "speaker"
            device: "speaker"
        },
        AudioList {
            objectName: "mic"
            device: "mic"
        }
    ]
}
