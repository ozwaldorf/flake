pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// The session actions, one per row. A fixed, short list: nothing to scroll and
// no empty state, since there is always exactly as much here as there ever is.
Item {
    id: root

    signal hoverChanged(bool hovered)

    // what the list wants to be, for the container that sizes and animates it
    readonly property real wantedHeight: list.implicitHeight

    clip: true

    Column {
        id: list

        width: parent.width
        spacing: 1

        Repeater {
            model: Power.actions

            Rectangle {
                id: row

                required property var modelData

                readonly property bool waiting: Power.pending === row.modelData.key

                // Shutting down and restarting end the session; suspend comes
                // back from it. Only the two that do not return are marked
                // out, and only under the pointer: at rest the list is quiet.
                readonly property bool ends: row.modelData.key !== "suspend"

                implicitWidth: parent ? parent.width : 0
                implicitHeight: 30
                radius: 6

                // alpha zero rather than "transparent", which is transparent
                // black and drags the fade through black at both ends
                color: hover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter

                    text: row.modelData.label
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: !hover.hovered ? Theme.subtext0 : row.ends ? Theme.red : Theme.text

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }

                // Only while systemd is still deciding, which is a polkit
                // prompt standing in front of the panel more often than it is
                // latency.
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter

                    text: "Waiting"
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.surface2
                    visible: row.waiting
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.hoverChanged(hovered)
                }

                TapHandler {
                    onTapped: Power.run(row.modelData.key)
                }
            }
        }
    }
}
