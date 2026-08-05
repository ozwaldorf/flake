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

    signal hoverChanged(bool hovered)
    signal askRequested
    signal askDismissed

    readonly property bool connected: network.connected
    readonly property bool busy: network.stateChanging
    readonly property bool failed: Wifi.failedNetwork === network.name && Wifi.failure !== ""

    readonly property int rowHeight: 30

    implicitWidth: parent ? parent.width : 0
    implicitHeight: rowHeight + (asking ? key.height + Theme.spaceXs : 0)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    clip: true

    Rectangle {
        id: hitRow

        width: parent.width
        height: root.rowHeight
        radius: 6
        // alpha zero rather than "transparent", which is transparent black and
        // drags the fade through black at both ends
        color: hover.hovered || root.asking ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

        Behavior on color {
            ColorAnimation {
                duration: 160
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

            Rectangle {
                anchors.centerIn: parent
                implicitWidth: 11
                implicitHeight: 11
                radius: 5.5
                color: "transparent"
                border.width: 1.5
                border.color: Theme.blue
                visible: root.busy

                // gap in the ring, spun by the rotation below
                Rectangle {
                    x: 0
                    y: 0
                    implicitWidth: 5
                    implicitHeight: 5
                    color: Theme.surface0
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
            id: name

            anchors.left: lead.right
            anchors.leftMargin: Theme.spaceXs
            anchors.right: badges.left
            anchors.rightMargin: Theme.spaceSm
            anchors.verticalCenter: parent.verticalCenter

            text: root.network.name
            font.family: Theme.font
            font.pixelSize: 11
            color: root.failed ? Theme.red : Theme.subtext0
            elide: Text.ElideRight
        }

        Row {
            id: badges

            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs

            // padlock: a shackle over a body, small enough to read as a badge
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 10
                visible: Wifi.needsKey(root.network) || root.network.known

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
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
                    height: 6
                    radius: 1.5
                    color: Theme.overlay0
                }
            }

            WifiGlyph {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 15
                implicitHeight: 12
                bars: Wifi.bars(root.network.signalStrength)
                fill: Theme.subtext0
                dim: Theme.surface1
            }
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.hoverChanged(hovered)
        }

        TapHandler {
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
            NumberAnimation {
                duration: Theme.fadeDuration
            }
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
                    duration: 160
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

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.failed ? Wifi.failure : "Password"
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: root.failed ? Theme.red : Theme.surface2
                    visible: field.text.length === 0
                }
            }

            Text {
                id: joinLabel

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                text: "Join"
                font.family: Theme.font
                font.pixelSize: 10
                color: field.text.length > 0 ? Theme.blue : Theme.surface2

                HoverHandler {
                    cursorShape: field.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onHoveredChanged: root.hoverChanged(hovered)
                }

                TapHandler {
                    onTapped: root.submit()
                }
            }
        }

        HoverHandler {
            onHoveredChanged: root.hoverChanged(hovered)
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
