import QtQuick
import ".."

// A level as a thin track, set by dragging along it or tapping a point. The
// item is the hit area and is meant to be taller than the track drawn through
// its middle, so the four pixel line is not what has to be aimed at.
Item {
    id: root

    // 0-1, what the track shows while it is not being dragged
    property real value: 0

    property color fill: Theme.subtext0

    // Whether a drag reports every step or only where it was let go. Live
    // suits a level that answers at once; held suits one where each report
    // is costly or fights back, like a track position the player keeps
    // updating underneath the pointer.
    property bool live: true

    property int cursorShape: Qt.ArrowCursor

    readonly property bool dragging: drag.active
    readonly property bool hovered: hover.hovered

    signal moved(real fraction)

    // where an unreported drag currently is
    property real held: 0

    readonly property real shown: dragging && !live ? held : Theme.clamp01(value)

    function at(x) {
        return Theme.clamp01(x / width);
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Theme.barThickness
        radius: height / 2
        color: Qt.alpha(Theme.surface2, 0.55)

        Rectangle {
            width: parent.width * root.shown
            height: parent.height
            radius: parent.radius
            color: root.fill

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                }
            }

            // followed straight while dragged, and eased otherwise so a level
            // arriving in steps does not jump
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation {
                    duration: Theme.trackDuration
                    easing.type: Easing.OutQuint
                }
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: root.cursorShape
    }

    DragHandler {
        id: drag

        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onCentroidChanged: {
            if (!active)
                return;
            if (root.live)
                root.moved(root.at(centroid.position.x));
            else
                root.held = root.at(centroid.position.x);
        }

        onActiveChanged: {
            if (root.live)
                return;
            if (active)
                root.held = Theme.clamp01(root.value);
            else
                root.moved(root.held);
        }
    }

    TapHandler {
        onTapped: eventPoint => root.moved(root.at(eventPoint.position.x))
    }
}
