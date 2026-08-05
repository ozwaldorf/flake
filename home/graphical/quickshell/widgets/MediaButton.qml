pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import ".."

// Transport controls, drawn rather than typed so no icon font is required.
Rectangle {
    id: root

    required property string symbol

    signal triggered

    implicitWidth: 18
    implicitHeight: 18
    radius: 4
    // alpha zero rather than "transparent", which is transparent black and
    // drags the fade through black at both ends
    color: hover.hovered && enabled ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)
    opacity: enabled ? 1 : 0.35

    readonly property color fill: hover.hovered && enabled ? Theme.text : Theme.overlay1

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    Shape {
        anchors.centerIn: parent
        implicitWidth: 12
        implicitHeight: 12
        preferredRendererType: Shape.CurveRenderer
        visible: root.symbol !== "pause"

        // triangle: points left for prev, right for play and next
        ShapePath {
            id: tri

            readonly property bool back: root.symbol === "prev"

            fillColor: root.fill
            strokeColor: "transparent"

            startX: back ? 10.5 : 1.5
            startY: 2
            PathLine {
                x: tri.back ? 10.5 : 1.5
                y: 10
            }
            PathLine {
                x: tri.back ? 3 : 9
                y: 6
            }
        }

        // stop bar, on the side the triangle points toward
        ShapePath {
            id: stop

            readonly property real barX: root.symbol === "prev" ? 1 : 9.5

            fillColor: root.symbol === "play" ? "transparent" : root.fill
            strokeColor: "transparent"

            startX: barX
            startY: 2
            PathLine {
                x: stop.barX + 1.5
                y: 2
            }
            PathLine {
                x: stop.barX + 1.5
                y: 10
            }
            PathLine {
                x: stop.barX
                y: 10
            }
            PathLine {
                x: stop.barX
                y: 2
            }
        }
    }

    // pause: two bars
    Row {
        anchors.centerIn: parent
        spacing: 3
        visible: root.symbol === "pause"

        Repeater {
            model: 2

            Rectangle {
                implicitWidth: 3
                implicitHeight: 10
                radius: 1
                color: root.fill
            }
        }
    }

    // exposed so a containing panel can tell the pointer is still inside it
    readonly property bool hovered: hover.hovered

    HoverHandler {
        id: hover
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: root.triggered()
    }
}
