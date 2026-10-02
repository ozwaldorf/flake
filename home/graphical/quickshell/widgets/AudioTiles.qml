pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// Volume and microphone side by side over one shared device list.
//
// Volume takes two thirds: it carries the longer device name and is the one
// actually dragged, where the microphone is mostly muted and left alone.
TileGroup {
    id: root

    readonly property real unit: (width - tileRow.spacing) / 3

    joinLeft: joinedTo === "mic" ? width - unit : 0
    joinRight: joinedTo === "mic" ? width : unit * 2

    maxListHeight: 150

    VolumeSlider {
        width: root.unit * 2
        host: root.host
        device: "speaker"
        label: "Volume"
        expanded: root.open === "speaker"
        joined: root.joined && root.joinedTo !== "mic"

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
        expanded: root.open === "mic"
        joined: root.joined && root.joinedTo === "mic"

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
