import QtQuick
import ".."

// Placeholder shown in the sliver for marks that have no collapsed form, so the
// resting column reads as a complete set of slots rather than gaps. Sits in the
// same slot as the mark it stands in for and fades out as that mark fades in.
Rectangle {
    id: root

    required property bool expanded

    // true when the real mark has something to show, in which case no skeleton
    property bool filled: false

    // fills the slot it stands in for, so the sliver shows the item's real
    // extent rather than a token stub
    implicitWidth: expanded ? Theme.rail : Theme.sliver
    implicitHeight: parent ? parent.height : 0
    radius: 0

    color: Theme.surface1
    opacity: expanded || filled ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fadeDuration
        }
    }
}
