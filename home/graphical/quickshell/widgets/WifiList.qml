pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Networks in range, scrolling if there are more than fit.
Flickable {
    id: root

    // name of the network whose key field is open, or empty
    property string asking: ""

    signal hoverChanged(bool hovered)

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

        // Placeholder rather than an empty box: with the scan just started
        // there is a beat before anything is in range.
        Text {
            width: parent.width
            height: visible ? 30 : 0
            visible: Wifi.networks.length === 0
            verticalAlignment: Text.AlignVCenter
            leftPadding: Theme.spaceSm
            text: "Looking for networks..."
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.surface2
        }

        Repeater {
            model: Wifi.networks

            WifiRow {
                required property var modelData

                network: modelData
                asking: root.asking === modelData.name

                onHoverChanged: hovered => root.hoverChanged(hovered)
                onAskRequested: root.asking = modelData.name
                onAskDismissed: {
                    if (root.asking === modelData.name)
                        root.asking = "";
                }
            }
        }
    }
}
