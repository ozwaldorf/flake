pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// The session actions, one per row. A fixed, short list: nothing to scroll and
// no empty state, since there is always exactly as much here as there ever is.
ScrollList {
    Repeater {
        model: Power.actions

        ListRow {
            id: row

            required property var modelData

            readonly property bool waiting: Power.pending === modelData.key

            onTapped: Power.run(modelData.key)

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter

                text: row.modelData.label
                font.pixelSize: 11
                // Every action here ends the session, so each is marked out
                // under the pointer; at rest the list is quiet.
                color: row.hovered ? Theme.red : Theme.subtext0

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }
            }

            // Only while systemd is still deciding, which is a polkit prompt
            // standing in front of the panel more often than it is latency.
            Label {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter

                text: "Waiting"
                color: Theme.surface2
                visible: row.waiting
            }
        }
    }
}
