import QtQuick
import ".."

// One vertical meter. Width follows the rail like every other mark; the fill
// runs bottom to top.
Rectangle {
    id: root

    required property bool expanded

    // 0-100
    property int value: 0

    // fill colour at rest; past warnAt it switches to peach regardless
    property color fill: Theme.overlay0
    property int warnAt: 72

    // Each meter has its own row, so all three are present in both forms and
    // only the width animates, matching the workspace marks.
    implicitWidth: expanded ? Theme.meterWidth : Theme.sliver
    implicitHeight: Theme.meterHeight
    radius: 0
    color: Theme.surface1
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * root.value / 100
        radius: 0
        color: root.value > root.warnAt ? Theme.peach : root.fill

        Behavior on height {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutQuint
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 700
            }
        }
    }
}
