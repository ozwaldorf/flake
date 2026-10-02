pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One device in the list: name on the left, battery and state on the right.
// Clicking connects or disconnects; a paired device also offers to be
// forgotten, revealed on hover so the row stays quiet at rest.
ListRow {
    id: root

    required property var device

    // Read through here rather than off the device directly: BlueZ drops a
    // device that goes out of range, and the row outlives it by a moment.
    readonly property bool connected: device?.connected ?? false
    readonly property bool paired: device?.paired ?? false
    readonly property bool pairing: device?.pairing ?? false

    readonly property bool busy: Bluetooth.inFlight(device)

    readonly property int battery: Bluetooth.batteryPercent(device)
    readonly property bool hasBattery: battery >= 0

    onTapped: Bluetooth.activate(device)

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
            color: root.connected ? Theme.blue : Qt.alpha(Theme.blue, 0)
            border.width: root.connected ? 0 : 1
            border.color: Theme.overlay0
            visible: (root.connected || root.paired) && !root.busy

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }
        }

        Spinner {
            anchors.centerIn: parent
            running: root.busy
            gapColor: root.hovered ? Theme.surface0 : Theme.base
        }
    }

    Label {
        anchors.left: lead.right
        anchors.leftMargin: Theme.spaceXs
        anchors.right: trailing.left
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter

        text: Bluetooth.label(root.device)
        font.pixelSize: 11
        color: root.connected ? Theme.text : Theme.subtext0
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
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "Forget"
            color: forgetHover.hovered ? Theme.red : Theme.surface2
            visible: root.paired && root.hovered

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }

            HoverHandler {
                id: forgetHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.device.forget()
            }
        }

        // Battery, only for devices that report one and only while connected.
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.battery + "%"
            figures: true
            color: root.battery <= 20 ? Theme.peach : Theme.overlay0
            visible: root.hasBattery
        }

        // Small state word for anything the markers cannot carry on their own.
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.pairing ? "Pairing" : root.connected || root.paired ? "" : "Pair"
            color: Theme.surface2
            visible: text.length > 0
        }
    }
}
