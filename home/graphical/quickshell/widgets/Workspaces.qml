pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

// Workspace marks. Each is one Rectangle that morphs between a sliver bar and a
// square rail block.
//
// Focus travel is driven by a single per-mark focusAmount in [0,1]: length and
// colour are both interpolated from it by one animator, so they cannot drift
// apart. Because the outgoing mark's amount falls exactly as the incoming one
// rises, over the same duration and a symmetric curve, the column's total
// height stays constant for the whole transition.
Column {
    id: root

    required property bool expanded

    // constant in both forms: vertical layout does not move on expand
    spacing: Theme.wsGap

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: mark

            required property var modelData

            readonly property bool focused: modelData.focused
            readonly property bool occupied: modelData.toplevels.values.length > 0
            readonly property bool urgent: modelData.urgent

            // 0 when unfocused, 1 when focused; everything else derives from it
            property real focusAmount: focused ? 1 : 0

            Behavior on focusAmount {
                NumberAnimation {
                    duration: Theme.focusDuration
                    // symmetric: the reverse of this curve is itself, so the
                    // shrink and the grow mirror frame for frame
                    easing.type: Easing.InOutQuad
                }
            }

            // heights do not depend on expansion, so the column is vertically
            // static and only the width animates
            readonly property real restLength: occupied ? Theme.wsOccupiedLength : Theme.wsEmptyLength
            readonly property real focusLength: Theme.wsFocusedLength

            readonly property color restColor: urgent ? Theme.red : occupied ? Theme.overlay1 : root.expanded ? Theme.surface2 : Theme.surface1

            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: root.expanded ? Theme.wsWidth : Theme.sliver
            implicitHeight: restLength + (focusLength - restLength) * focusAmount

            // urgent keeps its own colour rather than being overridden by focus
            color: urgent ? Theme.red : Qt.tint(restColor, Qt.alpha(Theme.blue, focusAmount))

            // square in both forms; length alone carries state
            radius: 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // no Behavior on colour: focusAmount already drives it on exactly
            // the same clock as the length, and a second animator here would
            // put them back out of step

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: mark.modelData.activate()
            }
        }
    }
}
