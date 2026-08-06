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

    // Only on the way open: closing leaves the join where it was so the card
    // comes down under the one it belongs to.
    onOpenChanged: {
        if (open !== "")
            listCard.fromLeft = open === "speaker";
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
            joined: listCard.height > 0 && listCard.fromLeft

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
            joined: listCard.height > 0 && !listCard.fromLeft

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

    // A surface of its own, joined to the card it came from: the list is that
    // card opened up rather than something that happens to be underneath.
    //
    // Not clipped here: the bridge below reaches up out of these bounds to
    // meet the card. The list inside does its own clipping instead.
    Rectangle {
        id: listCard

        width: parent.width

        // Which card the list belongs to, held through a collapse rather than
        // following root.open, which clears the moment the card is clicked:
        // switching then swings the join across while it is still coming down.
        property bool fromLeft: true

        implicitHeight: root.open === "" ? 0 : Math.min(root.open === "speaker" ? sinkList.wantedHeight : sourceList.wantedHeight, root.listHeight) + Theme.spaceXs * 2

        radius: 9
        color: Theme.surfaceFill

        // squared where the card above meets it, eased so the two corners
        // trade shape as the join moves rather than jumping
        topLeftRadius: fromLeft ? 0 : radius
        topRightRadius: fromLeft ? radius : 0

        Behavior on topLeftRadius {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        Behavior on topRightRadius {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        // Bridges the gap the column leaves, under the open card alone. The
        // two are different widths, so it takes whichever one it is joining.
        Rectangle {
            id: bridge

            readonly property real unit: (listCard.width - Theme.spaceXs) / 3

            // Both edges are animated in their own right rather than a width
            // and a position derived from it: with x computed from an
            // animating width, travelling outward drags the near edge inward
            // first as the width shrinks, and only then slides out. Moving the
            // two edges directly, each simply goes where it is going.
            //
            // not readonly: a Behavior writes to what it animates
            property real leftEdge: listCard.fromLeft ? 0 : listCard.width - unit
            property real rightEdge: listCard.fromLeft ? unit * 2 : listCard.width

            x: leftEdge
            width: Math.max(0, rightEdge - leftEdge)

            Behavior on leftEdge {
                NumberAnimation {
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            Behavior on rightEdge {
                NumberAnimation {
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // exactly the gap, tracked as it animates: fixed at its final
            // height it laps onto the card while the gap is still opening, and
            // two translucent surfaces overlapping show as a line
            height: root.spacing
            y: -height

            color: listCard.color
            visible: listCard.height > 0
        }

        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: listCard
                host: root.host
            }
        }

        DropShadow {
            target: listCard
            elevation: 6
            strength: 0.35
        }

        // The bridge is its own rectangle above the card, so it needs its own
        // blur or it shows as an unfrosted strip across the join.
        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: bridge
                host: root.host
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        AudioList {
            id: sinkList

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
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

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
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
