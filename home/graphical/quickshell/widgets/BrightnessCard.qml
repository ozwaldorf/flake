pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Screen brightness: one track driving every panel that has a backlight, the
// internal one and any external monitor ddcci has registered. A card rather
// than a tile, since there is nothing to toggle, only a level to set.
Card {
    id: root

    // one wheel notch
    readonly property real step: 0.05

    readonly property real clamped: Theme.clamp01(Backlight.value)

    implicitHeight: body.implicitHeight + Theme.spaceSm * 2
    visible: Backlight.available

    // Polled only while this card is on screen, since a level can be changed
    // by the brightness keys or the monitor's own buttons.
    Component.onCompleted: Backlight.watch(true)
    Component.onDestruction: Backlight.watch(false)

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
        onWheel: event => Backlight.set(root.clamped + event.angleDelta.y / 120 * root.step)
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        Item {
            width: parent.width
            implicitHeight: 16

            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Brightness"
                font.pixelSize: 11
            }

            Label {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.clamped * 100) + "%"
                figures: true
                color: Theme.overlay0
            }
        }

        Item {
            width: parent.width
            implicitHeight: 20

            SunGlyph {
                id: sun

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                level: root.clamped
                fill: Theme.overlay2
            }

            LevelTrack {
                anchors.left: sun.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                value: root.clamped
                onMoved: f => Backlight.set(f)
            }
        }
    }
}
