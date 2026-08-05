pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Paired and discovered devices, scrolling if there are more than fit.
Flickable {
    id: root

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

        Text {
            width: parent.width
            height: visible ? 30 : 0
            visible: Bluetooth.listed.length === 0
            verticalAlignment: Text.AlignVCenter
            leftPadding: Theme.spaceSm
            text: "Looking for devices..."
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.surface2
        }

        Repeater {
            model: Bluetooth.listed

            BluetoothRow {
                required property var modelData

                device: modelData
                onHoverChanged: hovered => root.hoverChanged(hovered)
            }
        }
    }
}
