import QtQuick

// Strike through a glyph for an off or muted state, corner to corner across
// whatever it is placed in.
Rectangle {
    property bool shown: false

    // how far short of the full diagonal it stops
    property real inset: 2

    anchors.centerIn: parent
    width: Math.sqrt(parent.width * parent.width + parent.height * parent.height) - inset
    height: 1.6
    radius: height / 2
    rotation: -45
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Fade {}
    }
}
