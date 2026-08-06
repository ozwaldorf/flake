import QtQuick
import QtQuick.Shapes
import ".."

// A window of past readings as a filled line, oldest at the left, scaled to
// what the window actually contains so a quiet stretch still shows its shape.
// The axis down the side carries the range, which is what keeps that honest.
Item {
    id: root

    // oldest first
    property var values: []

    property color stroke: Theme.overlay1

    // formats an axis value; percentages and byte rates want different words
    property var format: v => Math.round(v) + ""

    implicitWidth: 132
    implicitHeight: 54

    readonly property int count: values ? values.length : 0

    // Range of the window. A flat line has no range of its own, so it is given
    // one and centred in it rather than drawn along an edge.
    readonly property real rawMax: count > 0 ? Math.max.apply(null, values) : 0
    readonly property real rawMin: count > 0 ? Math.min.apply(null, values) : 0

    readonly property real pad: Math.max((rawMax - rawMin) * 0.1, rawMax * 0.05, 1)

    // Nothing above this is meaningful for the reading; percentages stop at a
    // hundred and would otherwise be padded past it.
    property real limit: 100

    readonly property real ceiling: Math.min(limit, rawMax + pad)
    readonly property real floor: Math.max(0, rawMin - pad)
    readonly property real midpoint: (ceiling + floor) / 2

    // total slots the line is spaced for, so a filling buffer grows leftward
    // into the space instead of the line rescaling under itself each tick
    property int slots: 60

    function pointX(i) {
        // right aligned: the newest sample sits at the right edge and older
        // ones trail off to the left, so the line does not jump sideways as
        // the buffer fills
        return plot.width - (count - 1 - i) * step;
    }

    readonly property real step: count > 1 ? plot.width / (slots - 1) : plot.width

    function pointY(v) {
        const t = (v - floor) / Math.max(ceiling - floor, 0.0001);
        return plot.height - Math.max(0, Math.min(1, t)) * plot.height;
    }

    // Ceiling, midpoint and floor of the range, so the shape of the line can be
    // read against actual numbers rather than only against itself.
    Column {
        id: axis

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(maxLabel.implicitWidth, midLabel.implicitWidth, minLabel.implicitWidth)

        Text {
            id: maxLabel

            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: root.format(root.ceiling)
            font.family: Theme.font
            font.pixelSize: 8
            font.features: {
                "tnum": 1
            }
            color: Theme.overlay0
        }

        Item {
            width: parent.width
            height: parent.height - maxLabel.height - minLabel.height

            Text {
                id: midLabel

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.format(root.midpoint)
                font.family: Theme.font
                font.pixelSize: 8
                font.features: {
                    "tnum": 1
                }
                color: Theme.overlay0
            }
        }

        Text {
            id: minLabel

            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: root.format(root.floor)
            font.family: Theme.font
            font.pixelSize: 8
            font.features: {
                "tnum": 1
            }
            color: Theme.overlay0
        }
    }

    // Surface under the plot only, not under the axis: the numbers sit on the
    // tip's own fill, and the chart gets a well of its own to sit in.
    Rectangle {
        id: plot

        anchors.left: parent.left
        anchors.right: axis.left
        anchors.rightMargin: Theme.spaceXs
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        radius: 4

        // the wash the control centre's cards carry, here on the chart alone:
        // it is what sits on a surface rather than being one
        color: Qt.alpha(Theme.surface0, 0.5)

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            visible: root.count > 1

            // The fill and the line are one path: closing it down to the
            // baseline and back gives the area under the line without a second
            // traversal.
            ShapePath {
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

                        // down to the baseline and back under the oldest
                        // sample, so the area closes without doubling back
                        // over the line
                        pts.push(Qt.point(root.pointX(root.count - 1), plot.height));
                        pts.push(Qt.point(root.pointX(0), plot.height));
                        return pts;
                    }
                }
            }
        }

        // Placeholder while there is not yet a line to draw: a bare well reads
        // as broken, a baseline reads as empty.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 1
            color: Qt.alpha(root.stroke, 0.35)
            visible: root.count <= 1
        }
    }
}
