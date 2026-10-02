pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// Networks in range, scrolling if there are more than fit.
ScrollList {
    id: root

    // name of the network whose key field is open, or empty
    property string asking: ""

    // with the scan just started there is a beat before anything is in range
    placeholder: "Looking for networks..."
    empty: Wifi.networks.length === 0

    Repeater {
        model: Wifi.networks

        WifiRow {
            required property var modelData

            network: modelData
            asking: root.asking === modelData.name

            onAskRequested: root.asking = modelData.name
            onAskDismissed: {
                if (root.asking === modelData.name)
                    root.asking = "";
            }
        }
    }
}
