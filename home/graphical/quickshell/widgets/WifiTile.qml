pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Wifi toggle and network picker. The tile is the switch: tapping the puck
// flips the radio, tapping the body expands the list of what is in range.
Column {
    id: root

    signal hoverChanged(bool hovered)

    // Open state is held here rather than by the panel so collapsing the list
    // does not need to reach back through the layout.
    property bool expanded: false

    // name of the network whose key field is open, or empty
    property string asking: ""

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

    width: parent ? parent.width : 0
    spacing: Theme.spaceXs
    visible: Wifi.available

    // ---- the tile ----

    Rectangle {
        id: tile

        width: parent.width
        implicitHeight: 52
        radius: 9
        color: tileHover.hovered ? Theme.surface0 : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        // Round puck, filled when the radio is on. This is the switch: macOS
        // puts the state in the fill rather than in a separate toggle.
        Rectangle {
            id: puck

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: 34
            implicitHeight: 34
            radius: 17

            color: Wifi.enabled ? Theme.blue : Theme.surface1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.fadeDuration
                }
            }

            // brightens on hover without swapping the state colour
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: puckHover.hovered ? 0.12 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }
            }

            WifiGlyph {
                anchors.centerIn: parent
                bars: Wifi.enabled ? Wifi.bars(Wifi.strength) : 4
                off: !Wifi.enabled
                fill: Wifi.enabled ? Theme.crust : Theme.overlay1
                dim: Wifi.enabled ? Qt.alpha(Theme.crust, 0.35) : Theme.surface2
            }

            HoverHandler {
                id: puckHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.hoverChanged(hovered)
            }

            TapHandler {
                onTapped: {
                    Wifi.toggle();
                    if (!Wifi.enabled)
                        root.expanded = false;
                }
            }
        }

        Column {
            anchors.left: puck.right
            anchors.leftMargin: Theme.spaceSm
            anchors.right: chevron.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: "Wi-Fi"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text
                elide: Text.ElideRight
            }

            // One line of state, in priority order: what is wrong, what is
            // happening, or what you are on.
            Text {
                width: parent.width
                text: {
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
                font.family: Theme.font
                font.pixelSize: 10
                color: Wifi.connected && !Wifi.online ? Theme.peach : Theme.overlay0
                elide: Text.ElideRight
            }
        }

        // Chevron, rotating to point down when the list is out. Two strokes
        // rather than a glyph, matching the drawn transport controls.
        Item {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm + 2
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12

            opacity: Wifi.enabled ? 1 : 0
            visible: opacity > 0
            rotation: root.expanded ? 90 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }

            Rectangle {
                x: 4
                y: 1.5
                width: 1.6
                height: 6.5
                radius: 0.8
                color: tileHover.hovered ? Theme.text : Theme.overlay0
                transformOrigin: Item.BottomLeft
                rotation: -40
            }

            Rectangle {
                x: 4
                y: 5.5
                width: 1.6
                height: 6.5
                radius: 0.8
                color: tileHover.hovered ? Theme.text : Theme.overlay0
                transformOrigin: Item.TopLeft
                rotation: 40
            }
        }

        HoverHandler {
            id: tileHover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hoverChanged(hovered)
        }

        TapHandler {
            onTapped: {
                if (Wifi.enabled)
                    root.expanded = !root.expanded;
            }
        }
    }

    // ---- the list ----

    // Height is driven off the content so the panel above resizes with it,
    // capped so a busy area does not push the rest of the panel off screen.
    Item {
        id: listBox

        width: parent.width
        clip: true

        readonly property real full: Math.min(list.implicitHeight, 210)

        implicitHeight: root.expanded ? full : 0
        opacity: root.expanded ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }

        Flickable {
            anchors.fill: parent
            contentHeight: list.implicitHeight
            contentWidth: width
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: list

                width: parent.width
                spacing: 1

                // Placeholder rather than an empty box: with the scan just
                // started there is a beat before anything is in range.
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
    }
}
