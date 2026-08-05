import QtQuick
import QtQuick.Shapes
import ".."

// Microphone capsule in a cradle, drawn to match the speaker glyph's weight.
Item {
    id: root

    // struck through when muted
    property bool muted: false

    property color fill: Theme.text

    implicitWidth: 16
    implicitHeight: 14

    // capsule
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 1
        implicitWidth: 5
        implicitHeight: 8
        radius: 2.5
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // cradle: an arc under the capsule, open at the top
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: cradle

            readonly property real radius: 4.4
            readonly property real cx: root.width / 2
            readonly property real cy: 7.5

            strokeColor: root.fill
            strokeWidth: 1.4
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: cradle.cx - cradle.radius
            startY: cradle.cy

            PathArc {
                x: cradle.cx + cradle.radius
                y: cradle.cy
                radiusX: cradle.radius
                radiusY: cradle.radius
                direction: PathArc.Counterclockwise
            }
        }
    }

    // stem
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 11.9
        implicitWidth: 1.4
        implicitHeight: 2.1
        radius: 0.7
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // slash for the muted state
    Rectangle {
        anchors.centerIn: parent
        width: Math.sqrt(root.width * root.width + root.height * root.height) - 3
        height: 1.6
        radius: 0.8
        color: root.fill
        rotation: -45
        opacity: root.muted ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }
    }
}
