import QtQuick
import ".."

// The shell's one geometry animation: anything that changes shape or travels
// does it on this clock, so rows, corners and joins all land together.
NumberAnimation {
    duration: Theme.morphDuration
    easing.type: Easing.OutQuint
}
