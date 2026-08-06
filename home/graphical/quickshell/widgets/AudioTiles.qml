pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import ".."
import "../services"

// Volume and microphone side by side over one shared device list. Only one
// list is ever open: they are peers, and stacking two would push everything
// below them off the panel.
//
// Volume takes two thirds: it carries the longer device name and is the one
// actually dragged, where the microphone is mostly muted and left alone.
Column {
    id: root

    signal hoverChanged(bool hovered)

    // passed down to the cards, which each frost their own rectangle
    property var host: null

    // Which card's list is showing: "speaker", "mic", or empty. Held by
    // whatever lays these out rather than here, so opening a list anywhere in
    // the panel closes whichever one was already out.
    property string open: ""

    signal requestOpen(string name)

    readonly property int listHeight: 150

    width: parent ? parent.width : 0

    // A Column spaces around a zero height child, so with no list out the gap
    // would hang below the cards as bare padding.
    spacing: open === "" ? 0 : Theme.spaceXs

    Behavior on spacing {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    function toggle(name) {
        requestOpen(open === name ? "" : name);
    }

    Row {
        width: parent.width
        spacing: Theme.spaceXs

        readonly property real unit: (width - spacing) / 3

        VolumeSlider {
            width: parent.unit * 2
            host: root.host
            device: "speaker"
            label: "Volume"
            expanded: root.open === "speaker"

            value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
            muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

            onMoved: v => {
                if (Pipewire.defaultAudioSink?.audio)
                    Pipewire.defaultAudioSink.audio.volume = v;
            }
            onMuteToggled: {
                if (Pipewire.defaultAudioSink?.audio)
                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
            }
            onListToggled: root.toggle("speaker")
            onHoverChanged: hovered => root.hoverChanged(hovered)
        }

        VolumeSlider {
            width: parent.unit
            host: root.host
            device: "mic"
            label: "Mic"
            expanded: root.open === "mic"

            value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
            muted: Pipewire.defaultAudioSource?.audio?.muted ?? false

            onMoved: v => {
                if (Pipewire.defaultAudioSource?.audio)
                    Pipewire.defaultAudioSource.audio.volume = v;
            }
            onMuteToggled: {
                if (Pipewire.defaultAudioSource?.audio)
                    Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
            }
            onListToggled: root.toggle("mic")
            onHoverChanged: hovered => root.hoverChanged(hovered)
        }
    }

    // ---- the shared list ----

    Item {
        width: parent.width
        clip: true

        implicitHeight: root.open === "" ? 0 : Math.min(root.open === "speaker" ? sinkList.wantedHeight : sourceList.wantedHeight, root.listHeight)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        AudioList {
            id: sinkList

            width: parent.width
            height: parent.height
            device: "speaker"
            opacity: root.open === "speaker" ? 1 : 0
            visible: opacity > 0

            onHoverChanged: hovered => root.hoverChanged(hovered)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }

        AudioList {
            id: sourceList

            width: parent.width
            height: parent.height
            device: "mic"
            opacity: root.open === "mic" ? 1 : 0
            visible: opacity > 0

            onHoverChanged: hovered => root.hoverChanged(hovered)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
    }
}
