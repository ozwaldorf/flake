import QtQuick
import ".."

// The rim of a well cut into the drawer's surface: shaded along the top edge,
// where the lip overhangs it, and catching a faint line of light along the
// bottom. Laid over the well's own fill, filling it and sharing its rounding,
// so the gradient is clipped to the same shape without an offscreen pass.
Rectangle {
    id: root

    required property Item target

    // Either rim can be left off where the well continues past that edge
    // into another, as a tile does into the list opened under it.
    property bool rimTop: true
    property bool rimBottom: true

    anchors.fill: target
    radius: (target as Rectangle)?.radius ?? Theme.cardRadius
    color: "transparent"

    // a few pixels of shade under the lip, whatever the well's height
    readonly property real lip: Math.min(0.5, 7 / Math.max(height, 1))
    readonly property real edge: Math.min(0.5, 1.5 / Math.max(height, 1))

    gradient: Gradient {
        GradientStop {
            position: 0
            color: root.rimTop ? Qt.rgba(0, 0, 0, 0.45) : "transparent"
        }
        GradientStop {
            position: root.lip
            color: "transparent"
        }
        GradientStop {
            position: 1 - root.edge
            color: "transparent"
        }
        GradientStop {
            position: 1
            color: root.rimBottom ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        }
    }
}
