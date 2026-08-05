pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Wifi state, wrapped around Quickshell.Networking so the widgets never reach
// into the device list themselves. The backend is event driven off
// NetworkManager, so nothing here polls; the one exception is the scan, which
// only runs while a panel is actually showing the list.
Singleton {
    id: root

    readonly property bool available: Networking.backend === NetworkBackendType.NetworkManager && device !== null

    // First wifi device. Multi radio setups exist but the panel only ever
    // presents one, and NM picks the same one for its own default route.
    readonly property var device: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }

    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled

    // Currently associated network, or null. Held as the device's own network
    // rather than searched for by name so a hidden SSID still resolves.
    readonly property var active: {
        if (!device)
            return null;
        for (const n of device.networks.values) {
            if (n.connected)
                return n;
        }
        return null;
    }

    readonly property string ssid: active?.name ?? ""
    readonly property real strength: active?.signalStrength ?? 0

    // Connecting covers the whole association: NM reports the device as
    // Connecting through auth, DHCP and the connectivity check.
    readonly property bool connecting: device?.state === ConnectionState.Connecting
    readonly property bool connected: active !== null

    // Full only after NM's own connectivity check clears, so a captive portal
    // or a link with no route reads as limited rather than online.
    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
    readonly property bool portal: Networking.connectivity === NetworkConnectivity.Portal

    // Visible networks minus the active one, strongest first, one entry per
    // SSID. The backend lists an entry per access point, so a mesh shows the
    // same name several times; the strongest is the one you would join anyway.
    readonly property var networks: {
        if (!device)
            return [];

        const seen = {};
        const out = [];
        for (const n of device.networks.values) {
            if (n.connected || n.name === "")
                continue;
            const prev = seen[n.name];
            if (prev !== undefined) {
                if (n.signalStrength > out[prev].signalStrength)
                    out[prev] = n;
                continue;
            }
            seen[n.name] = out.length;
            out.push(n);
        }

        out.sort((a, b) => {
            // saved profiles first: they are the ones a click actually joins
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });

        // A dense area lists dozens of neighbours you will never join, and a
        // list that long is scrolled past rather than read. Saved profiles are
        // always kept, however weak, since those are the ones worth reaching.
        return out.filter((n, i) => n.known || i < listLimit);
    }

    readonly property int listLimit: 12

    // Scanning is the one expensive thing here and it only matters while a
    // list is on screen, so panels raise it and drop it with their own
    // visibility. Counted, since there is one panel per monitor.
    property int scanners: 0

    function scan(on) {
        scanners = Math.max(0, scanners + (on ? 1 : -1));
    }

    onScannersChanged: syncScanner()
    onDeviceChanged: syncScanner()

    function syncScanner() {
        if (device)
            device.scannerEnabled = scanners > 0;
    }

    function toggle() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // Last association failure, surfaced by the panel next to the network that
    // produced it. Cleared on the next attempt rather than on a timer so a bad
    // password stays visible until you retype it.
    property string failedNetwork: ""
    property string failure: ""

    function clearFailure() {
        failedNetwork = "";
        failure = "";
    }

    // A known network joins on its own; an unknown secured one needs a key, so
    // the panel asks for one and calls connectWithPsk instead.
    function connect(network) {
        clearFailure();
        network.connect();
    }

    function connectWithPsk(network, psk) {
        clearFailure();
        network.connectWithPsk(psk);
    }

    // secured networks need a key on first join; open and OWE do not
    function needsKey(network) {
        return !network.known && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    // 0-4, matching the arc count the indicator draws. The backend reports
    // strength as a fraction, not a percentage.
    function bars(strength) {
        if (strength >= 0.6)
            return 4;
        if (strength >= 0.4)
            return 3;
        if (strength >= 0.2)
            return 2;
        if (strength > 0)
            return 1;
        return 0;
    }

    // Failures arrive per network, so the connection is watched through a
    // Repeater over the device's list rather than a single handler: the object
    // that fails is not necessarily the one that was clicked.
    Instantiator {
        model: root.device?.networks ?? null

        delegate: QtObject {
            required property var modelData

            readonly property Connections conn: Connections {
                target: modelData

                function onConnectionFailed(reason) {
                    root.failedNetwork = modelData.name;
                    root.failure = reason === ConnectionFailReason.NoSecrets ? "Incorrect password" : reason === ConnectionFailReason.WifiAuthTimeout ? "Authentication timed out" : reason === ConnectionFailReason.WifiNetworkLost ? "Network out of range" : "Could not connect";
                }
            }
        }
    }
}
