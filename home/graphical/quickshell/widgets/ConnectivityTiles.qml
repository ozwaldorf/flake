pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Wifi and bluetooth side by side over one shared list area.
TileGroup {
    id: root

    // A machine with no bluetooth adapter, or no wifi, should not leave half
    // the row empty: the one tile there is takes the full width.
    readonly property bool bothTiles: Wifi.available && Bluetooth.available
    readonly property real cell: bothTiles ? (width - tileRow.spacing) / 2 : width

    // A radio going off takes its own list down with it, but must not close
    // the other tile's.
    readonly property bool wifiOn: Wifi.enabled
    readonly property bool bluetoothOn: Bluetooth.enabled

    onWifiOnChanged: {
        if (!wifiOn && open === "wifi")
            requestOpen("");
    }

    onBluetoothOnChanged: {
        if (!bluetoothOn && open === "bluetooth")
            requestOpen("");
    }

    // Scanning is driven from here rather than the tiles: it should follow
    // whichever list is actually on screen.
    onOpenChanged: {
        Wifi.scan(open === "wifi");
        Bluetooth.scan(open === "bluetooth");
        if (open !== "wifi")
            wifiList.asking = "";
    }

    Component.onDestruction: {
        if (open === "wifi")
            Wifi.scan(false);
        else if (open === "bluetooth")
            Bluetooth.scan(false);
    }

    ToggleTile {
        width: root.cell
        host: root.host
        visible: Wifi.available

        label: "Wi-Fi"
        on: Wifi.enabled
        listName: "wifi"
        expanded: root.open === "wifi"

        // One line of state, in priority order: what is wrong, what is
        // happening, or what you are on.
        status: {
            if (!Wifi.hardwareEnabled)
                return "Hardware off";
            if (!Wifi.enabled)
                return "Off";
            if (Wifi.connecting)
                return "Connecting...";
            if (!Wifi.connected)
                return "Not connected";
            if (Wifi.portal)
                return "Sign in required";
            if (!Wifi.online)
                return "No internet";
            return Wifi.ssid;
        }

        warn: Wifi.connected && !Wifi.online

        onToggled: Wifi.toggle()
        onListToggled: root.toggle("wifi")

        glyph: WifiGlyph {
            anchors.centerIn: parent
            bars: Wifi.enabled ? Wifi.bars(Wifi.strength) : 4
            off: !Wifi.enabled
            fill: Wifi.enabled ? Theme.crust : Theme.overlay1
            dim: Wifi.enabled ? Qt.alpha(Theme.crust, 0.35) : Theme.surface2
        }
    }

    ToggleTile {
        width: root.cell
        host: root.host
        visible: Bluetooth.available

        label: "Bluetooth"
        on: Bluetooth.enabled
        status: Bluetooth.summary
        listName: "bluetooth"
        expanded: root.open === "bluetooth"

        onToggled: Bluetooth.toggle()
        onListToggled: root.toggle("bluetooth")

        glyph: BluetoothGlyph {
            anchors.centerIn: parent
            off: !Bluetooth.enabled
            fill: Bluetooth.enabled ? Theme.crust : Theme.overlay1
        }
    }

    lists: [
        WifiList {
            id: wifiList
            objectName: "wifi"
        },
        BluetoothList {
            objectName: "bluetooth"
        }
    ]
}
