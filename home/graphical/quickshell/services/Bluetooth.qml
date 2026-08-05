pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bt

// Bluetooth state, wrapped around Quickshell.Bluetooth so the widgets never
// reach into BlueZ themselves. Event driven throughout; the one costly thing
// is discovery, which only runs while a panel is showing the list.
Singleton {
    id: root

    // The adapter arrives asynchronously over DBus, so everything downstream
    // has to tolerate it being null for the first moments after start.
    readonly property var adapter: Bt.Bluetooth.defaultAdapter

    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === Bt.BluetoothAdapterState.Blocked

    // Enabling and disabling are their own states: the radio takes a moment
    // and the tile should not read as already switched.
    readonly property bool busy: adapter?.state === Bt.BluetoothAdapterState.Enabling || adapter?.state === Bt.BluetoothAdapterState.Disabling

    readonly property var devices: Bt.Bluetooth.devices.values

    readonly property var connected: devices.filter(d => d.connected)
    readonly property bool anyConnected: connected.length > 0

    // What the tile reports under the name: the connected device when there is
    // one, and how many when there are several.
    readonly property string summary: {
        if (blocked)
            return "Blocked by hardware switch";
        if (!enabled)
            return "Off";
        if (connected.length === 1)
            return label(connected[0]);
        if (connected.length > 1)
            return connected.length + " devices connected";
        return "Not connected";
    }

    // Paired devices first and connected ones above those, then whatever
    // discovery has turned up. Within a group the order is stable by name, so
    // the list does not reshuffle underneath a pointer as signals fluctuate.
    readonly property var listed: {
        // Discovery turns up every beacon in the building: smart bulbs, other
        // people's earbuds, and a long tail of devices advertising nothing but
        // a MAC. Anything already paired is kept whatever it calls itself; the
        // rest have to have a name to be worth a row.
        const out = devices.filter(d => d.connected || d.paired || named(d));

        out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return label(a).localeCompare(label(b));
        });

        return out.filter((d, i) => d.connected || d.paired || i < listLimit);
    }

    readonly property int listLimit: 12

    // BlueZ falls back to the address when a device advertises no name, so an
    // unnamed device is one whose name is its own address in some spelling.
    function named(device) {
        const n = device.name || device.deviceName || "";
        if (n === "")
            return false;
        return n.replace(/[-:]/g, "").toUpperCase() !== (device.address || "").replace(/[-:]/g, "").toUpperCase();
    }

    // Discovery is the expensive part and only matters while a list is on
    // screen, so panels raise it and drop it with their own visibility.
    // Counted, since there is one panel per monitor.
    property int scanners: 0

    function scan(on) {
        scanners = Math.max(0, scanners + (on ? 1 : -1));
    }

    // discovery on a powered down adapter is an error, not a no-op
    readonly property bool wantDiscovery: scanners > 0 && enabled

    onWantDiscoveryChanged: syncDiscovery()

    // the adapter appears asynchronously, after the first request may already
    // have been made against nothing
    onAdapterChanged: syncDiscovery()

    // What we last asked BlueZ for. The adapter's own discovering property
    // reports what is actually running, which lags the request by a round trip,
    // so comparing against it re-issues a start that is already in flight and
    // BlueZ answers with "Operation already in progress".
    property bool requestedDiscovery: false

    function syncDiscovery() {
        if (!adapter)
            return;
        if (requestedDiscovery === wantDiscovery)
            return;
        requestedDiscovery = wantDiscovery;
        adapter.discovering = wantDiscovery;
    }

    // A reload tears down the panels without running their destructors, so the
    // count can come back raised over a discovery that is still running. Settle
    // both against the adapter once it is known.
    Component.onCompleted: {
        scanners = 0;
        requestedDiscovery = false;
    }

    function toggle() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    // An unnamed device is listed by address rather than as a blank row; BlueZ
    // reports the name late, or never for a device that does not advertise one.
    function label(device) {
        return device.name || device.deviceName || device.address || "Unknown device";
    }

    // Pairing is implied by connecting to something new: BlueZ refuses a
    // connect to an unpaired device, and the two step dance is not something
    // the panel should make you perform.
    function activate(device) {
        if (device.connected)
            device.disconnect();
        else if (device.paired || device.bonded)
            device.connect();
        else
            device.pair();
    }

    // A freshly paired device is not connected by BlueZ automatically, so
    // finish the job once pairing lands rather than leaving a paired but idle
    // row that needs a second click.
    Instantiator {
        model: Bt.Bluetooth.devices

        delegate: QtObject {
            required property var modelData

            readonly property Connections conn: Connections {
                target: modelData

                function onPairedChanged() {
                    if (modelData.paired && !modelData.connected)
                        modelData.connect();
                }
            }
        }
    }

    // True while a device is mid transition, so the rows do not have to import
    // the BlueZ enums to know when to show a spinner.
    function inFlight(device) {
        return device.state === Bt.BluetoothDeviceState.Connecting || device.state === Bt.BluetoothDeviceState.Disconnecting || device.pairing;
    }

    // Battery percentage, or -1 when the device does not report one. Reported
    // as a fraction, and only meaningful while the device is connected.
    function batteryPercent(device) {
        if (!device.batteryAvailable)
            return -1;
        return Math.max(0, Math.min(100, Math.round(device.battery * 100)));
    }
}
