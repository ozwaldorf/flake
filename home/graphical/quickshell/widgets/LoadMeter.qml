import QtQuick
import ".."

// One vertical meter. Width follows the rail like every other mark; the fill
// runs bottom to top.
Rectangle {
    id: root

    required property bool expanded

    // 0-100
    property int value: 0

    property color fill: Theme.overlay0

    // A second reading stacked on the first, for a meter carrying two halves
    // of one figure: the mark then says which half it is rather than only how
    // much there is of both. Off unless a colour is given.
    property int secondValue: 0
    property color secondFill: "transparent"
    readonly property bool split: secondFill.a > 0

    // what a tooltip calls this meter and what it reads, and whether the
    // pointer is on it
    property string label: ""
    property string detail: ""
    property string icon: ""
    property var history: []

    signal hoverChanged(bool hovered)

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
        id: primary

        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * root.value / 100
        radius: 0

        color: root.fill

        Behavior on height {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutQuint
            }
        }
    }

    // Stacked on the first rather than beside it: side by side halves the
    // width of each, and in the sliver that is three pixels apiece.
    Rectangle {
        anchors.bottom: primary.top
        width: parent.width
        height: root.split ? parent.height * root.secondValue / 100 : 0
        radius: 0
        color: root.secondFill

        Behavior on height {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutQuint
            }
        }
    }

    // Fixed size target spanning the rail, so expanding does not move it out
    // from under a stationary pointer and the sliver is not what has to be hit.
    Item {
        anchors.centerIn: parent
        width: Theme.rail
        height: parent.height

        HoverHandler {
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }
}
