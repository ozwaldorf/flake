pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Label beside the rail, naming whatever the pointer is over and what it
// currently reads.
//
// Its own layer surface rather than an item in the bar: the bar's window is
// only as wide as the rail and masked to it, so anything drawn outside would
// be clipped. Matches the tray menu, which is a layer surface for the same
// reason.
PanelWindow {
    id: root

    required property var screenData

    // which edge the rail is on, so the tip opens inward
    required property bool anchorRight

    required property string text

    // vertical centre of the mark this is labelling, in screen coordinates
    property real markY: 0

    property bool shown: false

    screen: screenData
    color: "transparent"
    visible: shown || fade.running

    anchors {
        left: !root.anchorRight
        right: root.anchorRight
        top: true
        bottom: true
    }

    implicitWidth: Theme.rail + Theme.spaceXs + 140
    exclusiveZone: 0

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the mark it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: tip

        // just past the rail, on whichever side it is anchored to
        x: root.anchorRight ? root.width - Theme.rail - Theme.spaceXs - width : Theme.rail + Theme.spaceXs
        y: Math.round(root.markY - height / 2)

        implicitWidth: label.implicitWidth + Theme.spaceSm * 2
        implicitHeight: label.implicitHeight + Theme.spaceSm

        // Same surface as the cards in the control centre. Those sit on the
        // panel and layer a half alpha wash over it; this stands on its own,
        // so it carries both to arrive at the same colour.
        radius: 9
        color: Theme.surfaceFill

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.alpha(Theme.surface0, 0.5)
        }

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: Theme.fadeDuration
            }
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: root.text
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.text
        }
    }

    // blur behind it like every other surface, dropped at the halfway point of
    // the fade so it does not linger as a ghost
    BackgroundEffect.blurRegion: Region {
        readonly property bool active: tip.opacity > 0.5

        x: tip.x
        y: tip.y
        width: active ? tip.width : 0
        height: active ? tip.height : 0
        radius: tip.radius
    }
}
