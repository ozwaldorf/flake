pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Screen brightness: one track driving every panel that has a backlight, the
// internal one and any external monitor ddcci has registered. A card rather
// than a tile, since there is nothing to toggle, only a level to set.
Rectangle {
    id: root

    signal hoverChanged(bool hovered)

    // one wheel notch
    readonly property real step: 0.05

    readonly property real clamped: Math.max(0, Math.min(1, Backlight.value))

    implicitHeight: body.implicitHeight + Theme.spaceSm * 2
    radius: 9
    visible: Backlight.available

    color: cardHover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0.5)

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    // Polled only while this card is on screen, since a level can be changed
    // by the brightness keys or the monitor's own buttons.
    Component.onCompleted: Backlight.watch(true)
    Component.onDestruction: Backlight.watch(false)

    HoverHandler {
        id: cardHover
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        Item {
            width: parent.width
            implicitHeight: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Brightness"
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(root.clamped * 100) + "%"
                font.family: Theme.font
                font.pixelSize: 10
                font.features: {
                    "tnum": 1
                }
                color: Theme.overlay0
            }
        }

        Item {
            width: parent.width
            implicitHeight: 20

            SunGlyph {
                id: sun

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                level: root.clamped
                fill: Theme.overlay2
            }

            Item {
                id: hit

                anchors.left: sun.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                Rectangle {
                    id: track

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.barThickness
                    radius: height / 2
                    color: Qt.alpha(Theme.surface2, 0.55)

                    Rectangle {
                        width: Math.max(0, parent.width * root.clamped)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.subtext0

                        Behavior on width {
                            enabled: !drag.active
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                }

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onCentroidChanged: {
                        if (active)
                            Backlight.set(centroid.position.x / track.width);
                    }
                }

                TapHandler {
                    onTapped: eventPoint => Backlight.set(eventPoint.position.x / track.width)
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => Backlight.set(root.clamped + event.angleDelta.y / 120 * root.step)
                }

                HoverHandler {
                    onHoveredChanged: root.hoverChanged(hovered)
                }
            }
        }
    }
}
