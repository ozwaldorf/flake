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

    // Holds the sliver width rather than growing with the rail. It only exists
    // while collapsed, so widening it on expand means watching it stretch to
    // full width and only then fade out, when what it should do is stay put
    // and get out of the way.
    implicitWidth: Theme.sliver
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
