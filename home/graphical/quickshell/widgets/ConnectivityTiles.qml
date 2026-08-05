pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Wifi and bluetooth side by side over one shared list area. Only one list is
// ever open: the tiles are peers, and stacking two open lists would push
// everything below them off the panel.
Column {
    id: root

    signal hoverChanged(bool hovered)

    // which tile's list is showing: "wifi", "bluetooth", or empty
    property string open: ""

    // cap on the list, past which it scrolls
    readonly property int listHeight: 200

    width: parent ? parent.width : 0
    spacing: Theme.spaceXs

    function toggle(name) {
        open = open === name ? "" : name;
    }

    // A radio going off takes its own list down with it, but must not close
    // the other tile's.
    readonly property bool wifiOn: Wifi.enabled
    readonly property bool bluetoothOn: Bluetooth.enabled

    onWifiOnChanged: {
        if (!wifiOn && open === "wifi")
            open = "";
    }

    onBluetoothOnChanged: {
        if (!bluetoothOn && open === "bluetooth")
            open = "";
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

    // ---- the pair ----

    Row {
        width: parent.width
        spacing: Theme.spaceXs

        // A machine with no bluetooth adapter, or no wifi, should not leave
        // half the row empty: the one tile there is takes the full width.
        readonly property int shown: (Wifi.available ? 1 : 0) + (Bluetooth.available ? 1 : 0)
        readonly property real cell: shown > 1 ? (width - spacing) / 2 : width

        ToggleTile {
            width: parent.cell
            visible: Wifi.available

            label: "Wi-Fi"
            on: Wifi.enabled
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
            onHoverChanged: hovered => root.hoverChanged(hovered)

            glyph: WifiGlyph {
                anchors.centerIn: parent
                bars: Wifi.enabled ? Wifi.bars(Wifi.strength) : 4
                off: !Wifi.enabled
                fill: Wifi.enabled ? Theme.crust : Theme.overlay1
                dim: Wifi.enabled ? Qt.alpha(Theme.crust, 0.35) : Theme.surface2
            }
        }

        ToggleTile {
            width: parent.cell
            visible: Bluetooth.available

            label: "Bluetooth"
            on: Bluetooth.enabled
            status: Bluetooth.summary
            expanded: root.open === "bluetooth"

            onToggled: Bluetooth.toggle()
            onListToggled: root.toggle("bluetooth")
            onHoverChanged: hovered => root.hoverChanged(hovered)

            glyph: BluetoothGlyph {
                anchors.centerIn: parent
                off: !Bluetooth.enabled
                fill: Bluetooth.enabled ? Theme.crust : Theme.overlay1
            }
        }
    }

    // ---- the shared list ----

    // Height follows whichever list is showing, so the panel above resizes
    // with it and the two lists cross fade rather than both taking space.
    Item {
        width: parent.width
        clip: true

        implicitHeight: root.open === "" ? 0 : Math.min(root.open === "wifi" ? wifiList.wantedHeight : bluetoothList.wantedHeight, root.listHeight)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        WifiList {
            id: wifiList

            width: parent.width
            height: parent.height
            opacity: root.open === "wifi" ? 1 : 0
            visible: opacity > 0

            onHoverChanged: hovered => root.hoverChanged(hovered)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }

        BluetoothList {
            id: bluetoothList

            width: parent.width
            height: parent.height
            opacity: root.open === "bluetooth" ? 1 : 0
            visible: opacity > 0

            onHoverChanged: hovered => root.hoverChanged(hovered)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
    }
}
