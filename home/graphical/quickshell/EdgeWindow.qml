import QtQuick
import Quickshell

// A layer surface down one side of a screen, against whichever edge the rail
// is on. Everything beside the rail opens from here, inward.
PanelWindow {
    required property var modelData

    // the rail is on the right hand edge, so this opens leftward
    required property bool anchorRight

    // Room past the content for the shadows it casts: the window is what
    // clips them, and one ending flush with the cards cuts their outer edge.
    property real shadowRoom: 16

    screen: modelData
    color: "transparent"
    exclusiveZone: 0

    anchors {
        left: !anchorRight
        right: anchorRight
        top: true
        bottom: true
    }
}
