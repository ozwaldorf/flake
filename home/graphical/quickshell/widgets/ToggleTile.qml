pragma ComponentBehavior: Bound

import QtQuick
import ".."

// Toggle tile with an expanding list under it: a round puck carrying the
// state, a name and status line, and a chevron. Tapping the puck flips the
// switch, tapping the body opens the list. Shared by the wifi and bluetooth
// controls, which differ only in their glyph and what fills the list.
Column {
    id: root

    required property string label

    // one line under the name, describing whatever is going on
    required property string status

    // drives the puck fill and whether the list can be opened at all
    required property bool on

    // painted in peach rather than the usual grey, for a connected but
    // degraded state the status line is warning about
    property bool warn: false

    // the puck's contents; given `tile.enabled` and the fill colours to use
    property alias glyph: glyphSlot.data

    // filled by whatever the list should contain
    property alias list: listSlot.data

    // cap on the expanded list, past which it scrolls
    property int listHeight: 210

    property bool expanded: false

    signal hoverChanged(bool hovered)
    signal toggled

    width: parent ? parent.width : 0
    spacing: Theme.spaceXs

    // closing the switch closes the list with it: an empty list under a
    // disabled radio is not worth the height
    onOnChanged: {
        if (!on)
            expanded = false;
    }

    Rectangle {
        id: tile

        width: parent.width
        implicitHeight: 52
        radius: 9
        // Faded to alpha zero rather than "transparent", which is transparent
        // black: interpolating to it drags the colour through black on the way
        // out and back through it on the way in.
        color: tileHover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        // Round puck, filled when the switch is on. This is the switch itself:
        // the state lives in the fill rather than in a separate control.
        Rectangle {
            id: puck

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter

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

        Column {
            anchors.left: puck.right
            anchors.leftMargin: Theme.spaceSm
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

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

        // rotates to point down when the list is out
        Chevron {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm + 2
            anchors.verticalCenter: parent.verticalCenter

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

        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hoverChanged(hovered)
        }

        TapHandler {
            onTapped: {
                if (root.on)
                    root.expanded = !root.expanded;
            }
        }
    }

    // Height is driven off the content so the panel above resizes with it,
    // capped so a busy area does not push the rest of the panel off screen.
    Item {
        id: listBox

        width: parent.width
        clip: true

        implicitHeight: root.expanded ? Math.min(listSlot.childrenRect.height, root.listHeight) : 0
        opacity: root.expanded ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }

        Flickable {
            anchors.fill: parent
            contentHeight: listSlot.childrenRect.height
            contentWidth: width
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Item {
                id: listSlot

                width: parent.width
                implicitHeight: childrenRect.height
            }
        }
    }
}
