pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Devices for one half of Pipewire, scrolling if there are more than fit.
Flickable {
    id: root

    // "speaker" for the sinks, "mic" for the sources
    required property string device

    signal hoverChanged(bool hovered)

    readonly property bool isSink: device === "speaker"
    readonly property var devices: isSink ? Audio.sinks : Audio.sources

    // what the list wants to be, for the container that caps and animates it
    readonly property real wantedHeight: list.implicitHeight

    contentHeight: list.implicitHeight
    contentWidth: width
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Column {
        id: list

        width: parent.width
        spacing: 1

        Repeater {
            model: root.devices

            Rectangle {
                id: entry

                required property var modelData

                readonly property bool active: Audio.isDefault(modelData, root.isSink)

                width: list.width
                implicitHeight: 26
                radius: 6
                color: entryHover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
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
                            duration: 160
                        }
                    }
                }

                Text {
                    anchors.left: marker.right
                    anchors.leftMargin: Theme.spaceSm
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    text: Audio.label(entry.modelData)
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: entry.active ? Theme.text : Theme.subtext0
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: entryHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.hoverChanged(hovered)
                }

                TapHandler {
                    onTapped: {
                        if (root.isSink)
                            Audio.setSink(entry.modelData);
                        else
                            Audio.setSource(entry.modelData);
                    }
                }
            }
        }
    }
}
