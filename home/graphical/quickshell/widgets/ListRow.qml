import QtQuick
import ".."

// One row in a disclosed list: a quiet background that lifts under the
// pointer, the whole row a single target.
Rectangle {
    id: root

    // held lit while something else is going on in the row
    property bool highlighted: false

    readonly property bool hovered: hover.hovered

    signal tapped

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 30
    radius: 6

    // alpha zero rather than "transparent", which is transparent black and
    // drags the fade through black at both ends
    color: hovered || highlighted ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverDuration
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.tapped()
    }
}
