pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// Paired and discovered devices, scrolling if there are more than fit.
ScrollList {
    placeholder: "Looking for devices..."
    empty: Bluetooth.listed.length === 0

    Repeater {
        model: Bluetooth.listed

        BluetoothRow {
            required property var modelData

            device: modelData
        }
    }
}
