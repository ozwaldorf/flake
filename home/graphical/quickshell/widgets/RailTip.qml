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

    // what the mark is, over what it currently reads
    required property string text
    property string detail: ""

    // nerd font glyph beside them, or empty for none
    property string icon: ""

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

    // room for the rail, the gap the panel also uses, and the widest reading a
    // meter is likely to produce; the tip itself sizes to its own content
    implicitWidth: Theme.rail + 8 + 160
    exclusiveZone: 0

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the mark it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: tip

        // just past the rail, on whichever side it is anchored to
        x: root.anchorRight ? root.width - Theme.rail - 8 - width : Theme.rail + 8
        y: Math.round(root.markY - height / 2)

        // padded like the cards, which inset their content by spaceSm on every
        // side rather than only across
        implicitWidth: lines.implicitWidth + Theme.spaceSm * 2 + (icon.visible ? icon.width + Theme.spaceSm : 0)
        implicitHeight: lines.implicitHeight + Theme.spaceSm * 2

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

        // Spans both rows rather than sitting on one, the way the connectivity
        // tiles put their puck beside a name over a status line.
        Text {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: Theme.overlay2
            visible: root.icon !== ""
        }

        // Name over reading, so the reading can be as long as it needs without
        // the name being pushed off or the tip running the width of the screen.
        Column {
            id: lines

            anchors.left: icon.visible ? icon.right : parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            Text {
                text: root.text
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.text
            }

            Text {
                text: root.detail
                font.family: Theme.font
                font.pixelSize: 10
                font.features: {
                    "tnum": 1
                }
                color: Theme.overlay1
                visible: root.detail.length > 0
            }
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
