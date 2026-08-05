pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Wifi toggle and network picker.
ToggleTile {
    id: root

    // name of the network whose key field is open, or empty
    property string asking: ""

    label: "Wi-Fi"
    on: Wifi.enabled
    visible: Wifi.available

    // One line of state, in priority order: what is wrong, what is happening,
    // or what you are on.
    status: {
        if (!Wifi.hardwareEnabled)
            return "Blocked by hardware switch";
        if (!Wifi.enabled)
            return "Off";
        if (Wifi.connecting)
            return "Connecting...";
        if (!Wifi.connected)
            return "Not connected";
        if (Wifi.portal)
            return Wifi.ssid + " - sign in required";
        if (!Wifi.online)
            return Wifi.ssid + " - no internet";
        return Wifi.ssid;
    }

    warn: Wifi.connected && !Wifi.online

    onToggled: Wifi.toggle()

    // Scanning runs only while the list is on screen. The tile alone shows the
    // active network, which NM reports without a scan.
    onExpandedChanged: {
        Wifi.scan(expanded);
        if (!expanded)
            asking = "";
    }

    Component.onDestruction: {
        if (expanded)
            Wifi.scan(false);
    }

    glyph: WifiGlyph {
        anchors.centerIn: parent
        bars: Wifi.enabled ? Wifi.bars(Wifi.strength) : 4
        off: !Wifi.enabled
        fill: Wifi.enabled ? Theme.crust : Theme.overlay1
        dim: Wifi.enabled ? Qt.alpha(Theme.crust, 0.35) : Theme.surface2
    }

    list: Column {
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
