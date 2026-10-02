pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Devices for one half of Pipewire, scrolling if there are more than fit.
ScrollList {
    id: root

    // "speaker" for the sinks, "mic" for the sources
    required property string device

    readonly property bool isSink: device === "speaker"

    Repeater {
        model: root.isSink ? Audio.sinks : Audio.sources

        ListRow {
            id: entry

            required property var modelData

            readonly property bool active: Audio.isDefault(modelData, root.isSink)

            implicitHeight: 26

            onTapped: {
                if (root.isSink)
                    Audio.setSink(entry.modelData);
                else
                    Audio.setSource(entry.modelData);
            }

            // filled dot on the device currently in use
            Rectangle {
                id: marker

                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 5
                implicitHeight: 5
                radius: 2.5
                color: entry.active ? Theme.blue : Qt.alpha(Theme.blue, 0)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }
            }

            Label {
                anchors.left: marker.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.label(entry.modelData)
                color: entry.active ? Theme.text : Theme.subtext0
                elide: Text.ElideRight
            }
        }
    }
}
