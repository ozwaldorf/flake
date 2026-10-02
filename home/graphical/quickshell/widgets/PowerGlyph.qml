import QtQuick
import QtQuick.Shapes
import ".."

// IEC power mark: a ring broken at the top with a stem standing in the gap.
// Drawn rather than typed so it carries the same stroke weight as the other
// glyphs on the tiles.
Item {
    id: root

    property color fill: Theme.text

    implicitWidth: 18
    implicitHeight: 14

    // The gap is stated as a half angle off vertical, so the arc and the stem
    // are placed from one number and stay centred on each other.
    readonly property real gap: 52
    readonly property real radius: 5.2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: ring

            readonly property real cx: root.width / 2
            readonly property real cy: root.height / 2 + 1
            readonly property real start: root.gap * Math.PI / 180
            readonly property real end: -root.gap * Math.PI / 180

            strokeColor: root.fill
            strokeWidth: 1.6
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            // Swept the long way round, from one side of the gap to the other,
            // so the opening lands at the top rather than the bottom.
            startX: ring.cx + root.radius * Math.sin(ring.start)
            startY: ring.cy - root.radius * Math.cos(ring.start)

            PathArc {
                x: ring.cx + root.radius * Math.sin(ring.end)
                y: ring.cy - root.radius * Math.cos(ring.end)
                radiusX: root.radius
                radiusY: root.radius
                useLargeArc: true
            }
        }
    }

    // Stem, standing in the break and reaching a little into the ring so the
    // two read as one mark rather than a bar hung above a circle.
    Rectangle {
        x: root.width / 2 - width / 2
        y: root.height / 2 + 1 - root.radius - 2.2
        implicitWidth: 1.6
        implicitHeight: 6.4
        radius: 0.8
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }
}
