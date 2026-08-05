pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One device in the list: name on the left, battery and state on the right.
// Clicking connects or disconnects; a paired device also offers to be
// forgotten, revealed on hover so the row stays quiet at rest.
Rectangle {
    id: root

    required property var device

    signal hoverChanged(bool hovered)

    readonly property bool busy: Bluetooth.inFlight(device)

    readonly property int battery: Bluetooth.batteryPercent(device)
    readonly property bool hasBattery: battery >= 0

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 30
    radius: 6
    // alpha zero rather than "transparent", which is transparent black and
    // drags the fade through black at both ends
    color: hover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    // Connection state marker, in the same slot the wifi rows use for their
    // saved profile dot.
    Item {
        id: lead

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16

        // filled when connected, hollow when merely paired, absent otherwise
        Rectangle {
            anchors.centerIn: parent
            implicitWidth: 5
            implicitHeight: 5
            radius: 2.5
            color: root.device.connected ? Theme.blue : Qt.alpha(Theme.blue, 0)
            border.width: root.device.connected ? 0 : 1
            border.color: Theme.overlay0
            visible: (root.device.connected || root.device.paired) && !root.busy

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            implicitWidth: 11
            implicitHeight: 11
            radius: 5.5
            color: "transparent"
            border.width: 1.5
            border.color: Theme.blue
            visible: root.busy

            Rectangle {
                x: 0
                y: 0
                implicitWidth: 5
                implicitHeight: 5
                color: hover.hovered ? Theme.surface0 : Theme.base
            }

            RotationAnimator on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }
    }

    Text {
        anchors.left: lead.right
        anchors.leftMargin: Theme.spaceXs
        anchors.right: trailing.left
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        text: Bluetooth.label(root.device)
        font.family: Theme.font
        font.pixelSize: 11
        color: root.device.connected ? Theme.text : Theme.subtext0
        elide: Text.ElideRight
    }

    Row {
        id: trailing

        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs

        // Forget, on hover only: a paired device you never use again is the
        // one thing you cannot do from a plain connect toggle.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Forget"
            font.family: Theme.font
            font.pixelSize: 10
            color: forgetHover.hovered ? Theme.red : Theme.surface2
            visible: root.device.paired && hover.hovered

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            HoverHandler {
                id: forgetHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.hoverChanged(hovered)
            }

            TapHandler {
                onTapped: root.device.forget()
            }
        }

        // Battery, only for devices that report one and only while connected.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.battery + "%"
            font.family: Theme.font
            font.pixelSize: 10
            font.features: {
                "tnum": 1
            }
            color: root.battery <= 20 ? Theme.peach : Theme.overlay0
            visible: root.hasBattery
        }

        // Small state word for anything the markers cannot carry on their own.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.device.pairing ? "Pairing" : root.device.connected ? "" : root.device.paired ? "" : "Pair"
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.surface2
            visible: text.length > 0
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.hoverChanged(hovered)
    }

    TapHandler {
        onTapped: Bluetooth.activate(root.device)
    }
}
