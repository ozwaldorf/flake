import QtQuick
import ".."

// Sun: a disc with rays around it, the rays reaching further as the level
// rises so the glyph carries the brightness the way the speaker's arcs carry
// volume.
Item {
    id: root

    // 0-1, driving how far the rays extend
    property real level: 1

    property color fill: Theme.text

    implicitWidth: 16
    implicitHeight: 14

    readonly property real unit: height / 14

    // How far a ray's near end sits from the centre. Not readonly: a Behavior
    // writes to what it animates, and one on a readonly property is an invalid
    // assignment.
    //
    // Sized so the rays stay inside the box at full extent: they reach this
    // far plus their own length, either side of the middle.
    property real reach: (3.2 + 1.2 * Math.max(0, Math.min(1, level))) * unit

    Behavior on reach {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuint
        }
    }

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: 6 * root.unit
        implicitHeight: 6 * root.unit
        radius: width / 2
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // Eight rays around the disc. Each is placed by trigonometry rather than
    // by rotating a child about an offset origin: a Rotation transform is not
    // an Item, so a binding to its parent inside it does not resolve to the
    // rectangle being rotated and the origin silently collapses.
    Repeater {
        model: 8

        Rectangle {
            required property int index

            readonly property real angle: index * 45 * Math.PI / 180
            readonly property real len: 2.4 * root.unit

            // centre of the ray, out along its angle from the glyph's middle
            readonly property real cx: root.width / 2 + Math.sin(angle) * (root.reach + len / 2)
            readonly property real cy: root.height / 2 - Math.cos(angle) * (root.reach + len / 2)

            x: cx - width / 2
            y: cy - height / 2
            width: 1.5 * root.unit
            height: len
            radius: width / 2
            color: root.fill
            opacity: 0.35 + 0.65 * Math.max(0, Math.min(1, root.level))

            // spun about its own centre, which needs no origin offset
            rotation: index * 45

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
    }
}
