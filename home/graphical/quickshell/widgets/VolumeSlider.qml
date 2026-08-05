pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."

// Level capsule: the fill is the track, with the device glyph inset at the
// left end and no knob. Dragging anywhere in the capsule sets the level;
// tapping the glyph mutes.
Item {
    id: root

    // what the glyph draws: "speaker" or "mic"
    required property string device

    property real value: 0
    property bool muted: false

    signal moved(real value)
    signal muteToggled

    // exposed so the panel can tell the pointer is still inside it
    signal hoverChanged(bool hovered)

    readonly property real clamped: Math.max(0, Math.min(1, value))

    // The glyph sits in the filled part once the level passes it, so it is
    // drawn in the fill's own contrast colour from that point on rather than
    // going illegible against it.
    readonly property bool glyphSubmerged: !muted && clamped * width > glyphSlot.x + glyphSlot.width

    implicitHeight: 30

    Rectangle {
        id: capsule

        anchors.fill: parent
        radius: height / 2

        // Translucent rather than a flat grey, so the panel's own blur carries
        // through the control instead of the capsule punching an opaque hole
        // in it. The fill above is translucent for the same reason, and only
        // reads as a level because it is lighter than the track behind it.
        color: Qt.alpha(Theme.surface2, 0.28)

        // border brightens on hover, matching the tray entries
        border.width: 1
        border.color: hover.hovered ? Theme.surface2 : Theme.surface1

        Behavior on border.color {
            ColorAnimation {
                duration: 160
            }
        }

        // The fill is the whole left hand portion of the capsule rather than a
        // bar inside it, so the control reads as one object being filled.
        //
        // Square cornered and masked to the capsule rather than carrying its
        // own radius: a rounded fill collapses into itself once it is narrower
        // than its own corner diameter, and Qt's clip is a rectangular scissor
        // that would leave the right hand end square against the capsule's
        // curve. The mask gives it the capsule's shape at every width.
        // Inset by the border rather than running to the capsule's edge: the
        // fill's masked curve and the border's own curve are two separate
        // antialiased edges, and landing them on the same pixels leaves the
        // rounding looking chewed.
        Item {
            anchors.fill: parent
            anchors.margins: capsule.border.width
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: capsuleMask
            }

            Rectangle {
                width: Math.max(0, parent.width * root.clamped)
                height: parent.height
                color: root.muted ? Qt.alpha(Theme.text, 0.18) : Qt.alpha(Theme.text, 0.45)

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
    }

    // Shape the fill is masked to: the capsule inset by its border, so the two
    // curves are concentric and never share an edge.
    Item {
        id: capsuleMask

        width: capsule.width - capsule.border.width * 2
        height: capsule.height - capsule.border.width * 2
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "black"
        }
    }

    // Glyph, inset at the left end and clickable to mute. Outside the capsule
    // in the item tree so the capsule's clip does not cut it, and so its tap
    // handler takes the pointer before the drag surface below.
    Item {
        id: glyphSlot

        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 14

        readonly property color tint: root.glyphSubmerged ? Theme.base : root.muted ? Theme.overlay0 : Theme.overlay2

        SpeakerGlyph {
            anchors.centerIn: parent
            visible: root.device === "speaker"
            muted: root.muted
            fill: glyphSlot.tint
            // arcs follow the level, so a quiet sink reads as quiet even
            // before you look at the fill
            arcs: root.clamped > 0.5 ? 2 : root.clamped > 0 ? 1 : 0
        }

        MicGlyph {
            anchors.centerIn: parent
            visible: root.device === "mic"
            muted: root.muted
            fill: glyphSlot.tint
        }

        HoverHandler {
            id: glyphHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hoverChanged(hovered)
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.muteToggled()
        }
    }

    // Drag surface over the capsule but under the glyph. Levels are taken from
    // the capsule's full width, so the fill tracks the pointer exactly.
    Item {
        anchors.fill: parent
        z: -1

        DragHandler {
            id: drag

            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onCentroidChanged: {
                if (active)
                    root.moved(Math.max(0, Math.min(1, centroid.position.x / capsule.width)));
            }
        }

        TapHandler {
            onTapped: eventPoint => root.moved(Math.max(0, Math.min(1, eventPoint.position.x / capsule.width)))
        }

        HoverHandler {
            id: hover
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }
}
