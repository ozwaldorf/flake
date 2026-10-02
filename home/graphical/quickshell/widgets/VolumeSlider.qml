pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One audio level as a card: a label row carrying the current device and a
// chevron, the level under it as a glyph beside a thin track. Tapping the glyph
// mutes.
//
// The device picker lives outside, in the TileGroup that lays these out: the
// two cards sit side by side and share one expanding list, so only one is ever
// open.
Card {
    id: root

    // what the glyph draws and which half of Pipewire this drives:
    // "speaker" for the default sink, "mic" for the default source
    required property string device

    required property string label

    property real value: 0
    property bool muted: false

    property bool expanded: false

    signal moved(real value)
    signal muteToggled
    signal listToggled

    readonly property bool isSink: device === "speaker"
    readonly property real clamped: Theme.clamp01(value)

    // one wheel notch, matching the increment the media keys use
    readonly property real step: 0.05

    readonly property var current: isSink ? Audio.sink : Audio.source

    // Set while a list is joined onto the bottom of this card, including the
    // whole of its collapse: rounding the corners the moment it is asked to
    // close leaves them curved against a list still on its way down.
    property bool joined: expanded

    implicitHeight: body.implicitHeight + Theme.spaceSm * 2

    // eased on the same clock as the list's travel, so the corner opens out as
    // the card comes down rather than snapping once it lands
    bottomLeftRadius: joined ? 0 : radius
    bottomRightRadius: joined ? 0 : radius

    Behavior on bottomLeftRadius {
        Morph {}
    }

    Behavior on bottomRightRadius {
        Morph {}
    }

    // Anywhere on the card rather than over the track alone: the level is what
    // the card is for, and aiming at a four pixel rail to change it is the
    // thing scrolling exists to avoid.
    //
    // Adjusts by a step rather than jumping to the pointer. Angle delta is in
    // eighths of a degree against a fifteen degree notch, so dividing by 120
    // gives whole notches; a free spinning wheel or a touchpad sends fractions
    // of one, and those accumulate into the same step.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.moved(Theme.clamp01(root.clamped + event.angleDelta.y / 120 * root.step))
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.spaceSm
        anchors.rightMargin: Theme.spaceSm

        // Centred rather than pinned to the top: a card held to a taller
        // neighbour's height would otherwise leave its content sitting high.
        anchors.verticalCenter: parent.verticalCenter

        spacing: Theme.spaceXs

        // ---- name and device ----

        Item {
            width: parent.width
            implicitHeight: 30

            Column {
                anchors.left: parent.left
                anchors.right: chevron.left
                anchors.rightMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                    width: parent.width
                    text: root.label
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                // What the level is driving, under the name rather than beside
                // it: at half a panel wide there is no room across for both.
                Label {
                    width: parent.width
                    text: Audio.label(root.current)
                    color: pickHover.hovered ? Theme.subtext0 : Theme.overlay0
                    elide: Text.ElideRight

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.hoverDuration
                        }
                    }
                }
            }

            // rotates to point down when the picker is out
            Chevron {
                id: chevron

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                open: root.expanded
                fill: pickHover.hovered ? Theme.text : Theme.overlay0
            }

            // The whole row opens the picker, not just the chevron: a 12px
            // target is not worth aiming at when the row is already there.
            HoverHandler {
                id: pickHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.listToggled()
            }
        }

        // ---- level ----

        // Glyph outside the track rather than inset in it, with the track
        // taking whatever width is left. The hit area is the whole row so the
        // 4px track is not what you have to aim at.
        Item {
            width: parent.width
            implicitHeight: 20

            Item {
                id: glyphSlot

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 14

                readonly property color tint: root.muted ? Theme.surface2 : Theme.overlay2

                SpeakerGlyph {
                    anchors.centerIn: parent
                    visible: root.isSink
                    muted: root.muted
                    fill: glyphSlot.tint
                    // arcs follow the level, so a quiet sink reads as quiet
                    // before you look at the track
                    arcs: root.clamped > 0.5 ? 2 : root.clamped > 0 ? 1 : 0
                }

                MicGlyph {
                    anchors.centerIn: parent
                    visible: !root.isSink
                    muted: root.muted
                    fill: glyphSlot.tint
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.muteToggled()
                }
            }

            LevelTrack {
                anchors.left: glyphSlot.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                value: root.clamped
                fill: root.muted ? Theme.surface2 : Theme.subtext0
                onMoved: f => root.moved(f)
            }
        }
    }
}
