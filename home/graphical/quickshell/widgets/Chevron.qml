import QtQuick
import ".."

// Disclosure chevron, drawn as two strokes rather than typed so it matches the
// other drawn glyphs. Points right when closed and down when open.
Item {
    id: root

    property bool open: false
    property color fill: Theme.overlay0

    // Sized so the arms clear the box on every side as it turns: they reach
    // arm past the vertex at the centre in whichever direction the rotation
    // points them.
    implicitWidth: arm * 2
    implicitHeight: arm * 2

    rotation: open ? 90 : 0

    Behavior on rotation {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    readonly property real arm: 6.2
    readonly property real spread: 42

    // Both strokes pivot about the vertex where they meet, and the vertex sits
    // at the item's centre so it coincides with the point Item.rotation turns
    // about. Centring the glyph's bounding box instead would put the vertex
    // off centre, and since the vertex is what the eye tracks the chevron
    // would appear to swing around rather than turn in place.
    readonly property real vertexX: width / 2
    readonly property real vertexY: height / 2

    Rectangle {
        x: root.vertexX - width / 2
        y: root.vertexY - root.arm
        width: 1.6
        height: root.arm
        radius: 0.8
        color: root.fill
        transformOrigin: Item.Bottom
        rotation: -root.spread

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    Rectangle {
        x: root.vertexX - width / 2
        y: root.vertexY
        width: 1.6
        height: root.arm
        radius: 0.8
        color: root.fill
        transformOrigin: Item.Top
        rotation: root.spread

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }
}
