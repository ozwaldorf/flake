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

    // passed down to the cards, which each frost their own rectangle
    property var host: null

    // Which tile's list is showing: "wifi", "bluetooth", or empty. Held by
    // whatever lays these out rather than here, so opening a list anywhere in
    // the panel closes whichever one was already out.
    property string open: ""

    signal requestOpen(string name)

    // cap on the list, past which it scrolls
    readonly property int listHeight: 200

    width: parent ? parent.width : 0

    // A Column still spaces around a zero height child, so with no list out
    // the gap would hang below the tiles as bare padding. Animated rather
    // than switched so it opens with the list rather than ahead of it.
    //
    // The gap stays even with a list open: the card reaches back up through it
    // on its own tile's side rather than the whole row closing up, so the join
    // is to that tile alone.
    spacing: open === "" ? 0 : Theme.spaceXs

    Behavior on spacing {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    function toggle(name) {
        requestOpen(open === name ? "" : name);
    }

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

        // Only on the way open: closing leaves the join where it was so the
        // card comes down under the tile it belongs to.
        if (open !== "")
            listCard.fromLeft = open === "wifi";
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
            host: root.host
            visible: Wifi.available

            label: "Wi-Fi"
            on: Wifi.enabled
            expanded: root.open === "wifi"
            joined: listCard.height > 0 && listCard.fromLeft

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
            host: root.host
            visible: Bluetooth.available

            label: "Bluetooth"
            on: Bluetooth.enabled
            status: Bluetooth.summary
            expanded: root.open === "bluetooth"
            joined: listCard.height > 0 && !listCard.fromLeft

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
    //
    // A surface of its own, rather than a list on the desktop: it is the tile
    // it came from, opened up. The two top corners on that tile's side stay
    // square so the list reads as hanging from it rather than as a separate
    // card that happens to be underneath.
    Rectangle {
        id: listCard

        width: parent.width

        // Not clipped here: the bridge below reaches up out of these bounds to
        // meet the tile. The list inside does its own clipping instead.

        // Which half the open tile occupies, and so which corners to square
        // and which side to bridge.
        //
        // Held through a collapse rather than following root.open, which
        // clears the moment the tile is clicked: the card is still on its way
        // down, and switching sides then swings the join across to the other
        // tile for the length of the animation.
        property bool fromLeft: true

        readonly property bool bothTiles: Wifi.available && Bluetooth.available

        implicitHeight: root.open === "" ? 0 : Math.min(root.open === "wifi" ? wifiList.wantedHeight : bluetoothList.wantedHeight, root.listHeight) + Theme.spaceXs * 2

        radius: 9
        color: Theme.surfaceFill

        // Squared where the tile above meets it. With only one tile there is
        // nothing to pick between, so the whole top edge joins.
        topLeftRadius: bothTiles && !fromLeft ? radius : 0
        topRightRadius: bothTiles && fromLeft ? radius : 0


        // Bridges the gap the column leaves, under the open tile alone: the
        // list belongs to that tile, so it reaches back to that one and not to
        // its neighbour. Square at both ends, being the middle of a join.
        Rectangle {
            id: bridge

            x: listCard.fromLeft || !listCard.bothTiles ? 0 : listCard.width - width
            width: listCard.bothTiles ? (listCard.width - Theme.spaceXs) / 2 : listCard.width

            // Exactly the gap, tracking it as it opens rather than fixed at
            // its final size: the spacing animates from nothing, so a fixed
            // height laps onto the tile for the length of the animation. The
            // card's own top edge closes the join, so reaching past it only
            // doubles the fill and shows as a seam.
            height: root.spacing
            y: -height
            color: listCard.color
            visible: listCard.height > 0
        }

        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: listCard
                host: root.host
            }
        }

        // The bridge is its own rectangle above the card, so it needs its own
        // blur or it shows as an unfrosted strip across the join.
        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: bridge
                host: root.host
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        WifiList {
            id: wifiList

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
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

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
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
