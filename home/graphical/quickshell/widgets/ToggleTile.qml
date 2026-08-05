pragma ComponentBehavior: Bound

import QtQuick
import ".."

// Toggle tile: a round puck carrying the state over a name and status line,
// with a chevron marking that it has a list to open. Tapping the puck flips
// the switch, tapping the body opens the list.
//
// The list itself lives outside the tile, in whatever lays these out: two
// tiles sit side by side and share one expanding area below them, so only one
// list is ever open.
Rectangle {
    id: root

    required property string label

    // one line under the name, describing whatever is going on
    required property string status

    // drives the puck fill and whether the list can be opened at all
    required property bool on

    // painted in peach rather than the usual grey, for a connected but
    // degraded state the status line is warning about
    property bool warn: false

    // the puck's contents; given the fill colours to use
    property alias glyph: glyphSlot.data

    property bool expanded: false

    signal hoverChanged(bool hovered)
    signal toggled
    signal listToggled

    // puck, the gap under it, both text lines and the padding either end
    implicitHeight: Theme.spaceSm * 2 + 34 + Theme.spaceXs + labels.implicitHeight
    radius: 9

    // Faded to alpha zero rather than "transparent", which is transparent
    // black: interpolating to it drags the colour through black on the way out
    // and back through it on the way in.
    color: tileHover.hovered || expanded ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    // Round puck, filled when the switch is on. This is the switch itself: the
    // state lives in the fill rather than in a separate control.
    Rectangle {
        id: puck

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceSm
        anchors.top: parent.top
        anchors.topMargin: Theme.spaceSm

        implicitWidth: 34
        implicitHeight: 34
        radius: 17

        color: root.on ? Theme.blue : Theme.surface1

        Behavior on color {
            ColorAnimation {
                duration: Theme.fadeDuration
            }
        }

        // brightens on hover without swapping the state colour
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.text
            opacity: puckHover.hovered ? 0.12 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
        }

        Item {
            id: glyphSlot

            anchors.centerIn: parent
            width: 18
            height: 14
        }

        HoverHandler {
            id: puckHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hoverChanged(hovered)
        }

        TapHandler {
            onTapped: root.toggled()
        }
    }

    // rotates to point down when this tile's list is out
    Chevron {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: puck.verticalCenter

        open: root.expanded
        fill: tileHover.hovered ? Theme.text : Theme.overlay0

        opacity: root.on ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }
    }

    // Name and state below the puck rather than beside it: side by side these
    // tiles are half a panel wide, and a row would leave the status line no
    // room to say anything.
    Column {
        id: labels

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceSm
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm
        anchors.top: puck.bottom
        anchors.topMargin: Theme.spaceXs
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.text
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.status
            font.family: Theme.font
            font.pixelSize: 10
            color: root.warn ? Theme.peach : Theme.overlay0
            elide: Text.ElideRight
        }
    }

    HoverHandler {
        id: tileHover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.hoverChanged(hovered)
    }

    TapHandler {
        onTapped: {
            if (root.on)
                root.listToggled();
        }
    }
}
