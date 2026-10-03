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

    // A second series over the same axis, for two halves of one reading. Both
    // are scaled to whichever runs higher, so the lines are read against each
    // other rather than each filling the plot on a scale of its own.
    property var secondValues: []
    property color secondStroke: Theme.overlay0

    readonly property int secondCount: secondValues ? secondValues.length : 0
    readonly property bool split: secondCount > 1

    // Formats an axis value. Given the range's ceiling too, so a formatter
    // working in scaled units can pick one for the whole axis rather than
    // letting each label choose its own and reading in mixed units.
    property var format: (v, ceiling) => Math.round(v) + ""

    // Shared by the three axis labels, which are one legend and have no reason
    // to be set apart.
    property int axisSize: 9

    // the ceiling, midpoint and floor down the side; off where the chart is
    // too short to carry three lines of figures
    property bool showAxis: true

    // the faint ground under the plot; off where the chart bleeds into the
    // well it sits in rather than sitting in a box of its own
    property bool wash: true

    // The area under the line fading out toward the baseline rather than one
    // even tint, for a chart large enough to carry it.
    property bool glow: false

    property real lineWidth: 1.2

    implicitWidth: 132
    implicitHeight: 72

    readonly property int count: values ? values.length : 0

    // Range of the window. A flat line has no range of its own, so it is given
    // one and centred in it rather than drawn along an edge.
    // Across both series where there are two, so one axis carries them both.
    // Samples at the head of the window left out of the range, though still
    // drawn: readings taken while the source was still settling would
    // otherwise set the scale for the whole window.
    property int skipLeading: 0

    // what the range is taken from: the window less its unsettled head, or
    // all of it when that would leave nothing
    readonly property var scaled: count > skipLeading ? values.slice(skipLeading) : values
    readonly property var secondScaled: secondCount > skipLeading ? secondValues.slice(skipLeading) : secondValues

    readonly property real rawMax: Math.max(scaled.length > 0 ? Math.max.apply(null, scaled) : 0, secondScaled.length > 0 ? Math.max.apply(null, secondScaled) : 0)
    readonly property real rawMin: scaled.length > 0 ? Math.min(Math.min.apply(null, scaled), secondScaled.length > 0 ? Math.min.apply(null, secondScaled) : Infinity) : 0

    // Nothing above this is meaningful for the reading; a percentage stops at
    // a hundred and would otherwise be padded past it. Bytes have no such
    // ceiling, so they leave it alone.
    property real limit: Infinity

    // A tenth of the range above the peak, so the line has room to breathe
    // rather than running along the top edge. A flat window has no range of
    // its own, so it is given one and centred in it.
    readonly property real headroom: Math.max((rawMax - rawMin) * 0.1, rawMax * 0.1, 1)

    readonly property real ceiling: Math.min(limit, rawMax + headroom)
    readonly property real floor: Math.max(0, rawMin - (rawMax > rawMin ? 0 : headroom))
    readonly property real midpoint: (ceiling + floor) / 2

    // total slots the line is spaced for, so a filling buffer grows leftward
    // into the space instead of the line rescaling under itself each tick
    property int slots: 60

    // what the axis down the side needs, which is whatever its widest label is
    readonly property real axisWidth: Math.max(maxLabel.implicitWidth, midLabel.implicitWidth, minLabel.implicitWidth)

    function pointX(i) {
        // right aligned: the newest sample sits at the right edge and older
        // ones trail off to the left, so the line does not jump sideways as
        // the buffer fills
        return plot.width - (count - 1 - i) * step;
    }

    // The second series against its own length, so two buffers that have
    // filled to different depths still end level at the newest sample.
    function secondPointX(i) {
        return plot.width - (secondCount - 1 - i) * step;
    }

    readonly property real step: count > 1 ? plot.width / (slots - 1) : plot.width

    // The range the line is actually drawn against, eased toward the one the
    // axis states so a rescale settles the line into its new shape rather than
    // jumping it there. The labels name the target straight away.
    property real shownCeiling: ceiling
    property real shownFloor: floor

    // Whether the line has been drawn against its range yet. A chart handed
    // its whole history at once, as one is when its drawer opens, takes its
    // range outright rather than easing to it from the empty chart's, which
    // reads as the scale settling in front of you.
    property bool primed: false

    onCountChanged: {
        if (count < 2)
            primed = false;
        else if (!primed)
            Qt.callLater(() => primed = count > 1);
    }

    Behavior on shownCeiling {
        enabled: root.primed

        NumberAnimation {
            duration: Theme.levelDuration
            easing.type: Easing.OutQuad
        }
    }

    Behavior on shownFloor {
        enabled: root.primed

        NumberAnimation {
            duration: Theme.levelDuration
            easing.type: Easing.OutQuad
        }
    }

    function pointY(v) {
        const t = (v - shownFloor) / Math.max(shownCeiling - shownFloor, 0.0001);
        return plot.height - Math.max(0, Math.min(1, t)) * plot.height;
    }

    // Time between samples. When set, each new sample slides in from the
    // right over that interval rather than the whole line stepping left the
    // moment it lands, so the chart reads as continuous. The line is drawn one
    // sample behind for it, which over a two minute window is not noticed.
    property int interval: 0

    // how far the line still sits to the right of its resting place, in steps
    property real shift: 0

    // the previous sample count, so a window arriving all at once when the tip
    // opens is put up as it stands rather than slid in
    property int lastCount: 0

    onValuesChanged: {
        if (interval > 0 && lastCount > 1 && count > 1)
            scroll.restart();
        lastCount = count;
    }

    NumberAnimation {
        id: scroll

        target: root
        property: "shift"
        from: 1
        to: 0
        duration: root.interval
    }

    // Ceiling, midpoint and floor of the range, so the shape of the line can be
    // read against actual numbers rather than only against itself.
    Column {
        id: axis

        anchors.right: parent.right
        visible: root.showAxis
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.showAxis ? root.axisWidth : 0

        Text {
            id: maxLabel

            width: parent.width
            horizontalAlignment: Text.AlignRight
            text: root.format(root.ceiling, root.ceiling)
            font.family: Theme.font
            font.pixelSize: root.axisSize
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
                text: root.format(root.midpoint, root.ceiling)
                font.family: Theme.font
                font.pixelSize: root.axisSize
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
            text: root.format(root.floor, root.ceiling)
            font.family: Theme.font
            font.pixelSize: root.axisSize
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
        anchors.rightMargin: root.showAxis ? Theme.spaceXs : 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        radius: root.wash ? 4 : 0

        // the wash the control centre's cards carry, here on the chart alone:
        // it is what sits on a surface rather than being one
        color: root.wash ? Qt.alpha(Theme.surface0, 0.5) : "transparent"

        // the incoming sample slides in from past the right edge
        clip: true

        Shape {
            x: root.shift * root.step
            width: parent.width
            height: parent.height
            preferredRendererType: Shape.CurveRenderer
            visible: root.count > 1

            // The fill and the line are one path: closing it down to the
            // baseline and back gives the area under the line without a second
            // traversal.
            ShapePath {
                strokeColor: root.stroke
                strokeWidth: root.lineWidth

                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: plot.height

                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.stroke, root.glow ? 0.4 : 0.18)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.stroke, root.glow ? 0 : 0.18)
                    }
                }
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                Behavior on strokeColor {
                    ColorAnimation {
                        duration: Theme.glyphDuration
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

        // The second series, over the first. A line only, where the first
        // carries a filled area: two washes over one another read as a third
        // colour where they cross, and neither line stays legible through it.
        Shape {
            x: root.shift * root.step
            width: parent.width
            height: parent.height
            preferredRendererType: Shape.CurveRenderer
            visible: root.split

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.secondStroke
                strokeWidth: root.lineWidth
                joinStyle: ShapePath.RoundJoin
                capStyle: ShapePath.RoundCap

                Behavior on strokeColor {
                    ColorAnimation {
                        duration: Theme.glyphDuration
                    }
                }

                startX: root.split ? root.secondPointX(0) : 0
                startY: root.split ? root.pointY(root.secondValues[0]) : 0

                PathPolyline {
                    path: {
                        const pts = [];
                        if (!root.split)
                            return pts;

                        for (let i = 0; i < root.secondCount; i++)
                            pts.push(Qt.point(root.secondPointX(i), root.pointY(root.secondValues[i])));

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
