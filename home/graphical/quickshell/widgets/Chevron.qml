import QtQuick
import ".."

// Disclosure chevron, drawn as two strokes rather than typed so it matches the
// other drawn glyphs. Points right when closed and down when open.
Item {
    id: root

    property bool open: false
    property color fill: Theme.overlay0

    implicitWidth: 12
    implicitHeight: 12

    rotation: open ? 90 : 0

    Behavior on rotation {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    readonly property real arm: 6.2
    readonly property real spread: 42

    // Both strokes pivot about the vertex where they meet. Measured from that
    // vertex the glyph reaches sideways to the arm tips and an equal distance
    // above and below, so its bounding box is reach wide and 2 * rise tall.
    //
    // Item.rotation turns about the item's centre, so that box has to be
    // centred on the item or the chevron swings off its own axis as it opens.
    // Placing the vertex half the box's width to the left of centre is what
    // centres it.
    readonly property real reach: arm * Math.sin(spread * Math.PI / 180)
    readonly property real rise: arm * Math.cos(spread * Math.PI / 180)

    readonly property real vertexX: width / 2 - reach / 2
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
