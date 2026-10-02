pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

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

    // the rail's own 0 to 1 travel, which the marks' width follows
    required property real reveal

    // the screen this rail is on; only its own workspaces are listed
    required property var screenData

    // constant in both forms: vertical layout does not move on expand
    spacing: Theme.wsGap

    Repeater {
        // The live model rather than a filtered copy, with other monitors'
        // marks hidden: a rebuilt list would recreate every mark on each
        // workspace change and cut their focus travel short.
        model: Niri.workspaces

        Rectangle {
            id: mark

            required property int wsId
            required property string output
            required property bool active
            required property bool urgent
            required property int windows

            // the Column skips hidden children, so this takes no slot
            visible: output === root.screenData.name

            // the workspace showing on this screen, whether or not the screen
            // itself has focus: each rail says what is on its own monitor
            readonly property bool focused: active
            readonly property bool occupied: windows > 0

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

            implicitWidth: Theme.sliver + (Theme.wsWidth - Theme.sliver) * root.reveal
            implicitHeight: restLength + (focusLength - restLength) * focusAmount

            // urgent keeps its own colour rather than being overridden by focus
            color: urgent ? Theme.red : Qt.tint(restColor, Qt.alpha(Theme.blue, focusAmount))

            // square in both forms; length alone carries state
            radius: 0

            // no Behavior on colour: focusAmount already drives it on exactly
            // the same clock as the length, and a second animator here would
            // put them back out of step

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(mark.wsId)
            }
        }
    }
}
