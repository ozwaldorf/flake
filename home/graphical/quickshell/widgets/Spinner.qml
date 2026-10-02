import QtQuick
import ".."

// A ring with a gap in it, turning while something is in flight.
Rectangle {
    id: root

    property bool running: false

    // matched to whatever the spinner sits on, so the gap reads as a break
    property color gapColor: Theme.surface0

    implicitWidth: 11
    implicitHeight: 11
    radius: width / 2
    color: "transparent"
    border.width: 1.5
    border.color: Theme.blue
    visible: running

    Rectangle {
        implicitWidth: 5
        implicitHeight: 5
        color: root.gapColor
    }

    RotationAnimator on rotation {
        running: root.running
        from: 0
        to: 360
        duration: Theme.spinDuration
        loops: Animation.Infinite
    }
}
