import QtQuick
import QtQuick.Shapes
import ".."

// The bluetooth rune, drawn rather than typed so it matches the wifi arcs in
// weight and can be struck through when the radio is off.
Item {
    id: root

    // struck through when the radio is off
    property bool off: false

    property color fill: Theme.text

    implicitWidth: 18
    implicitHeight: 14

    // The rune is a bowtie crossed by a vertical stroke: two triangles meeting
    // at the centre, with the upper and lower points offset to one side.
    Shape {
        anchors.centerIn: parent
        implicitWidth: 9
        implicitHeight: 13
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.fill
            strokeWidth: 1.7
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            // up the left edge to the top point, down through the centre to the
            // bottom point, and back out to the left edge
            startX: 1
            startY: 3.5

            PathLine {
                x: 8
                y: 9.5
            }
            PathLine {
                x: 4.5
                y: 12.5
            }
            PathLine {
                x: 4.5
                y: 0.5
            }
            PathLine {
                x: 8
                y: 3.5
            }
            PathLine {
                x: 1
                y: 9.5
            }
        }
    }

    // slash for the disabled radio, drawn over the rune
    Rectangle {
        anchors.centerIn: parent
        width: Math.sqrt(root.width * root.width + root.height * root.height) - 2
        height: 1.6
        radius: 0.8
        color: root.fill
        rotation: -45
        opacity: root.off ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }
    }
}
