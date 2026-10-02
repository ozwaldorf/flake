pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One network in the list: name on the left, lock and signal on the right.
// Unknown secured networks expand a key field in place rather than opening a
// dialog, so the panel never loses the pointer to another surface.
Item {
    id: root

    required property var network

    // only one row in the list holds an open key field at a time
    property bool asking: false

    signal askRequested
    signal askDismissed

    readonly property bool connected: network.connected
    readonly property bool busy: network.stateChanging
    readonly property bool failed: Wifi.failedNetwork === network.name && Wifi.failure !== ""

    implicitWidth: parent ? parent.width : 0
    implicitHeight: hitRow.height + (asking ? key.height + Theme.spaceXs : 0)

    Behavior on implicitHeight {
        Morph {}
    }

    clip: true

    ListRow {
        id: hitRow

        width: parent.width
        highlighted: root.asking

        onTapped: {
            if (root.connected) {
                root.network.disconnect();
            } else if (Wifi.needsKey(root.network)) {
                if (root.asking)
                    root.askDismissed();
                else
                    root.askRequested();
            } else {
                Wifi.connect(root.network);
            }
        }

        // Spinner in place of the glyph while associating, so the row does not
        // change width as the state moves.
        Item {
            id: lead

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16

            // Small filled dot marking a saved profile, in place of nothing at
            // all: it is the only cue that a click will join without asking.
            Rectangle {
                anchors.centerIn: parent
                implicitWidth: 5
                implicitHeight: 5
                radius: 2.5
                color: Theme.overlay0
                visible: root.network.known && !root.busy
                opacity: 0.9
            }

            Spinner {
                anchors.centerIn: parent
                running: root.busy
            }
        }

        // padlock, ahead of the name: whether a network wants a key belongs
        // with what it is called, not stranded at the far edge of the row
        Item {
            id: lock

            anchors.left: lead.right
            anchors.leftMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 7 : 0
            height: 9
            visible: Wifi.needsKey(root.network) || root.network.known

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 5
                implicitHeight: 5
                radius: 2.5
                color: "transparent"
                border.width: 1.2
                border.color: Theme.overlay0
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 5.5
                radius: 1.5
                color: Theme.overlay0
            }
        }

        Label {
            anchors.left: lock.right
            anchors.leftMargin: lock.visible ? Theme.spaceXs : 0
            anchors.right: badges.left
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter

            text: root.network.name
            font.pixelSize: 11
            color: root.failed ? Theme.red : Theme.subtext0
            elide: Text.ElideRight
        }

        // Sized against the 11px name rather than the 15px the tiles use: at
        // that size the arcs outweigh the text they sit beside.
        WifiGlyph {
            id: badges

            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter

            implicitWidth: 12
            implicitHeight: 9
            bars: Wifi.bars(root.network.signalStrength)
            fill: Theme.overlay1
            dim: Theme.surface1
        }
    }

    // Key field, revealed under the row it belongs to. Focus follows the
    // reveal so the password can be typed without a second click.
    Item {
        id: key

        anchors.top: hitRow.bottom
        anchors.topMargin: Theme.spaceXs
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        opacity: root.asking ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Fade {}
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            radius: 6
            color: Theme.crust
            border.width: 1
            border.color: root.failed ? Theme.red : field.activeFocus ? Theme.blue : Theme.surface1

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: Theme.spaceSm
                anchors.rightMargin: joinLabel.width + Theme.space
                verticalAlignment: TextInput.AlignVCenter

                echoMode: TextInput.Password
                passwordCharacter: "*"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text
                selectionColor: Theme.blue
                selectedTextColor: Theme.crust
                clip: true

                onAccepted: root.submit()

                Keys.onEscapePressed: root.askDismissed()

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.failed ? Wifi.failure : "Password"
                    font.pixelSize: 11
                    color: root.failed ? Theme.red : Theme.surface2
                    visible: field.text.length === 0
                }
            }

            Label {
                id: joinLabel

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                text: "Join"
                color: field.text.length > 0 ? Theme.blue : Theme.surface2

                HoverHandler {
                    cursorShape: field.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    onTapped: root.submit()
                }
            }
        }
    }

    function submit() {
        if (field.text.length === 0)
            return;
        Wifi.connectWithPsk(network, field.text);
        field.text = "";
        askDismissed();
    }

    onAskingChanged: {
        if (asking)
            field.forceActiveFocus();
        else
            field.text = "";
    }
}
