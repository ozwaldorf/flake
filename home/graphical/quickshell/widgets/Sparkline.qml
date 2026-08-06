import QtQuick
import QtQuick.Shapes
import ".."

// A window of past readings as a filled line, oldest at the left. Values are
// percentages, so the vertical scale is fixed at 0-100 rather than following
// the data: a graph that rescales itself makes a quiet stretch look as busy as
// a loaded one.
Item {
    id: root

    // oldest first
    property var values: []

    property color stroke: Theme.overlay1

    implicitWidth: 120
    implicitHeight: 28

    readonly property int count: values ? values.length : 0

    // Horizontal step between samples. The buffer fills from empty, so early on
    // it is spaced for the samples there are rather than stretching two points
    // across the whole width.
    readonly property real step: count > 1 ? width / (root.slots - 1) : width

    // total slots the line is spaced for, so a filling buffer grows leftward
    // into the space instead of the line rescaling under itself each tick
    property int slots: 60

    function pointX(i) {
        // right aligned: the newest sample sits at the right edge and older
        // ones trail off to the left, so the line does not jump sideways as
        // the buffer fills
        return width - (count - 1 - i) * step;
    }

    function pointY(v) {
        return height - Math.max(0, Math.min(100, v)) / 100 * height;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.count > 1

        // The fill and the line are one path: closing it down to the baseline
        // and back gives the area under the line without a second traversal.
        ShapePath {
            id: area

            fillColor: Qt.alpha(root.stroke, 0.18)
            strokeColor: root.stroke
            strokeWidth: 1.2
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: root.count > 1 ? root.pointX(0) : 0
            startY: root.count > 1 ? root.pointY(root.values[0]) : 0

            PathPolyline {
                path: {
                    const pts = [];
                    if (root.count < 2)
                        return pts;

                    for (let i = 0; i < root.count; i++)
                        pts.push(Qt.point(root.pointX(i), root.pointY(root.values[i])));

                    // down to the baseline and back under the oldest sample, so
                    // the area closes without doubling back over the line
                    pts.push(Qt.point(root.pointX(root.count - 1), root.height));
                    pts.push(Qt.point(root.pointX(0), root.height));
                    return pts;
                }
            }
        }
    }

    // Placeholder while there is not yet a line to draw: a bare box reads as
    // broken, a baseline reads as empty.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(root.stroke, 0.35)
        visible: root.count <= 1
    }
}
