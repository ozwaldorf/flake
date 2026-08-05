import QtQuick
import Quickshell
import ".."

// Rail only: digits need width the sliver does not have. Minute precision means
// the process is not woken once a second just to redraw.
//
// Fixed slot holding the digits and, while collapsed, a skeleton standing in
// for them. The slot never changes size, so the column above never shifts.
Item {
    id: root

    required property bool expanded

    implicitWidth: Theme.rail
    implicitHeight: digits.implicitHeight

    // only the digits fade; the root keeps full opacity for the skeleton
    property real reveal: expanded ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuint
        }
    }

    SkeletonMark {
        anchors.centerIn: parent
        expanded: root.expanded
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Hours over minutes rather than HH:mm on one line: two digits fit the rail
    // where five do not, and the colon carries no information stacked.
    Column {
        id: digits

        anchors.centerIn: parent
        spacing: 0
        opacity: root.reveal
        visible: opacity > 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH")
            font.family: Theme.font
            font.pixelSize: 14
            font.letterSpacing: 0.5
            color: Theme.text
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "mm")
            font.family: Theme.font
            font.pixelSize: 14
            font.letterSpacing: 0.5
            color: Theme.overlay2
        }

    }
}
