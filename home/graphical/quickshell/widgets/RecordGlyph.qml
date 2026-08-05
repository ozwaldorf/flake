import QtQuick
import ".."

// Record dot, becoming a stop square while running: the same mark every
// recorder uses, and the shape says which way the button goes.
Item {
    id: root

    property bool recording: false
    property color fill: Theme.text

    implicitWidth: 18
    implicitHeight: 14

    Rectangle {
        anchors.centerIn: parent

        // circle at rest, square while recording; the radius carries the whole
        // transition so it morphs rather than swapping shapes
        implicitWidth: root.recording ? 9 : 11
        implicitHeight: root.recording ? 9 : 11
        radius: root.recording ? 1.5 : 5.5
        color: root.fill

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuint
            }
        }
        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuint
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuint
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.fadeDuration
            }
        }
    }
}
