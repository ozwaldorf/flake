import QtQuick
import QtQuick.Shapes
import ".."

// Speaker cone with signal arcs, drawn to match the wifi glyph's weight. The
// arcs drop away as the level falls, so the glyph carries the level too.
Item {
    id: root

    // 0-2 arcs lit, or -1 to hold them all lit regardless of level
    property int arcs: 2

    // struck through when muted
    property bool muted: false

    property color fill: Theme.text

    implicitWidth: 16
    implicitHeight: 14

    // cone: a rectangle for the throat and a triangle opening to the right
    Shape {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 8
        implicitHeight: 11
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fill
            strokeColor: root.fill
            strokeWidth: 1.2
            joinStyle: ShapePath.RoundJoin

            Behavior on fillColor {
                ColorAnimation {
                    duration: 200
                }
            }
            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: 0.6
            startY: 4

            PathLine {
                x: 2.6
                y: 4
            }
            PathLine {
                x: 6
                y: 0.8
            }
            PathLine {
                x: 6
                y: 10.2
            }
            PathLine {
                x: 2.6
                y: 7
            }
            PathLine {
                x: 0.6
                y: 7
            }
        }
    }

    // Two arcs off the cone's mouth, concentric about it. Hidden while muted,
    // where the slash carries the state instead.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: root.muted ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }

        ShapePath {
            id: near

            readonly property real radius: 3.2

            strokeColor: root.arcs !== 0 ? root.fill : Qt.alpha(root.fill, 0.25)
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: 8.4
            startY: root.height / 2 - near.radius

            PathArc {
                x: 8.4
                y: root.height / 2 + near.radius
                radiusX: near.radius
                radiusY: near.radius
                direction: PathArc.Clockwise
            }
        }

        ShapePath {
            id: far

            readonly property real radius: 5.8

            strokeColor: root.arcs === -1 || root.arcs >= 2 ? root.fill : Qt.alpha(root.fill, 0.25)
            strokeWidth: 1.5
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: 8.4
            startY: root.height / 2 - far.radius

            PathArc {
                x: 8.4
                y: root.height / 2 + far.radius
                radiusX: far.radius
                radiusY: far.radius
                direction: PathArc.Clockwise
            }
        }
    }

    // slash for the muted state, drawn over the cone
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
