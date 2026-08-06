import QtQuick
import QtQuick.Shapes
import ".."

// A proportion as a ring, with the reading in the middle. For a figure that is
// a share of a fixed whole rather than a rate: an arc closing on a full circle
// says how much of it is gone in a way a line against a scaled axis does not.
//
// Drawn as a stroked arc rather than a filled wedge, so the empty remainder is
// as legible as the used part; a pie reads as one shape, a ring as two.
Item {
    id: root

    // 0-1, the share of the ring that is filled
    property real level: 0

    // what sits in the middle, and the line under it
    property string label: ""
    property string sublabel: ""

    property color fill: Theme.teal

    // past this the arc takes the warning colour, matching the meters
    property real warnAt: 0.72

    implicitWidth: 96
    implicitHeight: 96

    readonly property real thickness: Math.max(3, side * 0.085)
    readonly property real side: Math.min(width, height)
    readonly property real radius: (side - thickness) / 2

    readonly property real clamped: Math.max(0, Math.min(1, level))

    // Animated here rather than on the arc's own sweep: the dial and the
    // reading in the middle both follow this, so they cannot drift apart.
    property real amount: clamped

    Behavior on amount {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutQuint
        }
    }

    readonly property color arcColor: clamped > warnAt ? Theme.peach : fill

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The whole ring, as the ground the filled part is read against.
        ShapePath {
            fillColor: "transparent"
            strokeColor: Qt.alpha(Theme.surface2, 0.55)
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        // The filled part, opening from the top and running clockwise: twelve
        // o'clock is where a dial is read from, and Qt measures its angles from
        // three, so the start is pulled back a quarter turn.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.arcColor
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor {
                ColorAnimation {
                    duration: 700
                }
            }

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * root.amount
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Theme.font
            font.pixelSize: Math.round(root.side * 0.22)
            font.features: {
                "tnum": 1
            }
            color: Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.sublabel
            font.family: Theme.font
            font.pixelSize: Math.round(root.side * 0.11)
            font.features: {
                "tnum": 1
            }
            color: Theme.overlay0
            visible: text !== ""
        }
    }
}
