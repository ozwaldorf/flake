import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// The desktop beside an open drawer, as one surface: a press anywhere on it
// puts the drawer away and goes no further.
//
// Mapped for good and switched by its region, like the pages: a surface
// mapped as a drawer opens takes the pointer for its first frame, which the
// rail reads as leaving.
PanelWindow {
    id: root

    required property var modelData
    required property bool anchorRight

    property bool active: false

    // how far the rail and drawer reach in from the screen edge, left out
    property real pushWidth: 0

    signal dismissed

    screen: modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "quickshell-dismiss"

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    mask: Region {
        x: root.anchorRight ? 0 : root.pushWidth
        width: root.active ? Math.max(0, root.width - root.pushWidth) : 0
        height: root.active ? root.height : 0
    }

    BackgroundEffect.blurRegion: Region {
        width: 0
        height: 0
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.dismissed()
    }
}
