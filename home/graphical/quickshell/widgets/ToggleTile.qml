pragma ComponentBehavior: Bound

import QtQuick
import ".."

// Toggle tile: the switch on the left spanning a name over the current
// connection, with a chevron on the right. Tapping the puck flips the switch,
// tapping the body opens the list.
//
// The list itself lives outside the tile, in the TileGroup that lays these out:
// two tiles sit side by side and share one expanding area below them, so only
// one list is ever open.
Card {
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

    // Some tiles are a switch and nothing more: no list to disclose, so no
    // chevron and the body is not a second target.
    property bool hasList: true

    // Whether the puck is a switch at all. A tile that only discloses a list
    // has nothing to flip, so the puck stops being a target of its own and is
    // left to the body, and the list opens without waiting on an on state
    // that never becomes true.
    property bool switchable: true

    // Overridable for tiles whose on state is not simply "enabled", like a
    // recorder that is red while it is running.
    property color puckFill: on ? Theme.blue : Theme.surface1

    // the list this opens in its group, by name
    property string listName: ""

    property bool expanded: false

    signal toggled

    // the puck, for an expanded view to show in its own header
    readonly property Item lead: puck
    signal listToggled

    // whichever is taller, the puck or the two text rows, plus padding
    implicitHeight: Theme.spaceSm * 2 + Math.max(puck.implicitHeight, rows.implicitHeight)
    cursorShape: Qt.PointingHandCursor

    // Round puck, filled when the switch is on. This is the switch itself: the
    // state lives in the fill rather than in a separate control. It spans both
    // text rows rather than sitting on one of them.
    Rectangle {
        id: puck

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: 34
        implicitHeight: 34
        radius: 17

        color: root.puckFill

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
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutQuad
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
        }

        // Only where there is a switch to flip. Without one the puck falls
        // through to the tile's own handler, so the whole card discloses.
        TapHandler {
            enabled: root.switchable
            onTapped: root.toggled()
        }
    }

    // rotates to point down when this tile's list is out
    Chevron {
        id: chevron

        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        open: root.expanded
        fill: root.hovered ? Theme.text : Theme.overlay0

        opacity: root.hasList && (root.on || !root.switchable) ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Fade {}
        }
    }

    Column {
        id: rows

        anchors.left: puck.right
        anchors.leftMargin: Theme.spaceSm
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

        Label {
            width: parent.width
            text: root.status
            color: root.warn ? Theme.peach : Theme.overlay0
            elide: Text.ElideRight
            // collapsed when there is nothing to say, so the label centres
            visible: text !== ""
        }
    }

    TapHandler {
        onTapped: {
            // With no list to open, the whole tile is the switch rather than
            // only the puck: there is nothing else it could mean.
            if (!root.hasList)
                root.toggled();
            else if (root.on || !root.switchable)
                root.listToggled();
        }
    }
}
