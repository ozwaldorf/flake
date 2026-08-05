import QtQuick
import ".."

// Sun: a disc with rays around it, filling out as the level rises so the glyph
// carries the brightness the way the speaker's arcs carry volume.
Item {
    id: root

    // 0-1, driving how far the rays extend
    property real level: 1

    property color fill: Theme.text

    implicitWidth: 16
    implicitHeight: 14

    readonly property real unit: height / 14

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: 6 * root.unit
        implicitHeight: 6 * root.unit
        radius: width / 2
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // Eight rays, growing with the level. Drawn as rotated children of a
    // centred item so each one only needs its angle.
    Item {
        anchors.centerIn: parent
        width: 0
        height: 0

        Repeater {
            model: 8

            Rectangle {
                required property int index

                readonly property real reach: (4.2 + 1.4 * root.level) * root.unit

                x: -0.7 * root.unit
                y: -reach - 1.6 * root.unit
                width: 1.4 * root.unit
                height: 2.2 * root.unit
                radius: width / 2
                color: root.fill
                opacity: 0.35 + 0.65 * root.level

                transform: Rotation {
                    origin.x: 0.7 * root.unit
                    origin.y: parent.reach + 1.6 * root.unit
                    angle: parent.index * 45
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuint
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }
            }
        }
    }
}
