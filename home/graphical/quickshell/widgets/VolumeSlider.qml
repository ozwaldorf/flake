pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One audio level as a card: a label row carrying the current device and a
// chevron, the level under it as a glyph beside a thin track. Tapping the glyph
// mutes.
//
// The device picker lives outside, in whatever lays these out: the two cards
// sit side by side and share one expanding list, so only one is ever open.
Rectangle {
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

    // exposed so the panel can tell the pointer is still inside it
    signal hoverChanged(bool hovered)
    signal listToggled

    readonly property bool isSink: device === "speaker"
    readonly property real clamped: Math.max(0, Math.min(1, value))

    // one wheel notch, matching the increment the media keys use
    readonly property real step: 0.05

    readonly property var current: isSink ? Audio.sink : Audio.source

    implicitHeight: body.implicitHeight + Theme.spaceSm * 2
    radius: 9

    // Same resting fill and the same lift on hover as the toggle tiles, so
    // every card in the panel is one kind of surface.
    color: cardHover.hovered || expanded ? Theme.surface0 : Qt.alpha(Theme.surface0, 0.5)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    // Behind the content so the children keep their own hover states; this
    // only reports whether the pointer is over the card at all. Reported
    // upward too, since the panel dismisses on losing the pointer and the
    // card's own body is neither the track nor the label row.
    HoverHandler {
        id: cardHover
        onHoveredChanged: root.hoverChanged(hovered)
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

                Text {
                    width: parent.width
                    text: root.label
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.text
                    elide: Text.ElideRight
                }

                // What the level is driving, under the name rather than beside
                // it: at half a panel wide there is no room across for both.
                Text {
                    width: parent.width
                    text: Audio.label(root.current)
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: pickHover.hovered ? Theme.subtext0 : Theme.overlay0
                    elide: Text.ElideRight

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
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
                onHoveredChanged: root.hoverChanged(hovered)
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
                    onHoveredChanged: root.hoverChanged(hovered)
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.muteToggled()
                }
            }

            // Taller than the track so the hit target is not a 4px sliver.
            Item {
                id: hit

                anchors.left: glyphSlot.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                Rectangle {
                    id: track

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.barThickness
                    radius: height / 2
                    color: Qt.alpha(Theme.surface2, 0.55)

                    Rectangle {
                        width: Math.max(0, parent.width * root.clamped)
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Theme.surface2 : Theme.subtext0

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        Behavior on width {
                            enabled: !drag.active
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                }

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onCentroidChanged: {
                        if (active)
                            root.moved(Math.max(0, Math.min(1, centroid.position.x / track.width)));
                    }
                }

                TapHandler {
                    onTapped: eventPoint => root.moved(Math.max(0, Math.min(1, eventPoint.position.x / track.width)))
                }

                // Scroll adjusts by a step rather than jumping to the pointer.
                // Angle delta is in eighths of a degree and a notch is 15
                // degrees, so dividing by 120 gives whole notches; a free
                // spinning wheel or a touchpad sends fractions of one and
                // those accumulate into the same step.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        root.moved(Math.max(0, Math.min(1, root.clamped + event.angleDelta.y / 120 * root.step)));
                    }
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: root.hoverChanged(hovered)
                }
            }
        }
    }
}
