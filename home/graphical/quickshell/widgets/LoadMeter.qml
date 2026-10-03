import QtQuick
import ".."

// One vertical meter. Width follows the rail like every other mark; the fill
// runs bottom to top.
Rectangle {
    id: root

    // the rail's own 0 to 1 travel, which the width follows
    required property real reveal

    // 0-100
    property int value: 0

    property color fill: Theme.overlay0

    // A second reading stacked on the first, for a meter carrying two halves
    // of one figure: the mark then says which half it is rather than only how
    // much there is of both. Off unless a colour is given.
    property int secondValue: 0
    property color secondFill: "transparent"
    readonly property bool split: secondFill.a > 0

    // Each meter has its own row, so all three are present in both forms and
    // only the width animates, matching the workspace marks.
    implicitWidth: Theme.sliver + (Theme.meterWidth - Theme.sliver) * reveal
    implicitHeight: Theme.meterHeight
    radius: 0

    // Cut into the rail like the drawers' wells, so the level reads as
    // filling a recess rather than standing on the surface.
    color: Theme.wellFill
    clip: true

    Rectangle {
        id: primary

        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.height * root.value / 100
        radius: 0

        color: root.fill

        Behavior on height {
            NumberAnimation {
                duration: Theme.levelDuration
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
                duration: Theme.levelDuration
                easing.type: Easing.OutQuint
            }
        }
    }

    // over the fill as well as the empty part, so the rim shades whatever
    // level reaches up under it
    Inset {
        target: root
    }
}
