pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Bluetooth toggle and device picker.
ToggleTile {
    id: root

    label: "Bluetooth"
    on: Bluetooth.enabled
    status: Bluetooth.summary
    visible: Bluetooth.available

    onToggled: Bluetooth.toggle()

    // Discovery runs only while the list is on screen; paired devices are
    // listed either way, since BlueZ knows them without scanning.
    onExpandedChanged: Bluetooth.scan(expanded)

    Component.onDestruction: {
        if (expanded)
            Bluetooth.scan(false);
    }

    glyph: BluetoothGlyph {
        anchors.centerIn: parent
        off: !Bluetooth.enabled
        fill: Bluetooth.enabled ? Theme.crust : Theme.overlay1
    }

    list: Column {
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
