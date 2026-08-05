import QtQuick
import QtQuick.Shapes
import ".."

// The signal arcs, drawn rather than typed so the inactive arcs can be dimmed
// individually. Three arcs over a dot, like every other wifi indicator.
Item {
    id: root

    // 0-4: dot plus three arcs. 0 leaves only the dot lit.
    property int bars: 4

    // struck through when the radio is off
    property bool off: false

    property color fill: Theme.text
    property color dim: Theme.surface2

    implicitWidth: 18
    implicitHeight: 14

    // Arcs are concentric about a point below the glyph, so they nest the way
    // the drawn ones do rather than being three scaled copies.
    readonly property real originX: width / 2
    readonly property real originY: height - 1.5

    // 58 degrees either side of vertical, matching the spread of the system
    // glyph. Precomputed since every arc endpoint needs both components.
    readonly property real spreadSin: Math.sin(58 * Math.PI / 180)
    readonly property real spreadCos: Math.cos(58 * Math.PI / 180)

    // lit unless the radio is off or the signal does not reach this arc
    function arcColor(minBars) {
        return !off && bars >= minBars ? fill : dim;
    }

    // Three arcs rather than a Repeater: a Repeater delegate must be an Item
    // and ShapePath is not one.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: inner

            readonly property real radius: 4.5

            strokeColor: root.arcColor(2)
            strokeWidth: 1.9
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: root.originX - inner.radius * root.spreadSin
            startY: root.originY - inner.radius * root.spreadCos

            PathArc {
                x: root.originX + inner.radius * root.spreadSin
                y: root.originY - inner.radius * root.spreadCos
                radiusX: inner.radius
                radiusY: inner.radius
                direction: PathArc.Clockwise
            }
        }

        ShapePath {
            id: middle

            readonly property real radius: 8.75

            strokeColor: root.arcColor(3)
            strokeWidth: 1.9
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: root.originX - middle.radius * root.spreadSin
            startY: root.originY - middle.radius * root.spreadCos

            PathArc {
                x: root.originX + middle.radius * root.spreadSin
                y: root.originY - middle.radius * root.spreadCos
                radiusX: middle.radius
                radiusY: middle.radius
                direction: PathArc.Clockwise
            }
        }

        ShapePath {
            id: outer

            readonly property real radius: 13

            strokeColor: root.arcColor(4)
            strokeWidth: 1.9
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 200
                }
            }

            startX: root.originX - outer.radius * root.spreadSin
            startY: root.originY - outer.radius * root.spreadCos

            PathArc {
                x: root.originX + outer.radius * root.spreadSin
                y: root.originY - outer.radius * root.spreadCos
                radiusX: outer.radius
                radiusY: outer.radius
                direction: PathArc.Clockwise
            }
        }
    }

    // the dot, lit whenever the radio is on at all
    Rectangle {
        x: root.originX - width / 2
        y: root.originY - height / 2
        implicitWidth: 3.4
        implicitHeight: 3.4
        radius: 1.7
        color: root.arcColor(1)

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // slash for the disabled radio, drawn over the arcs
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
