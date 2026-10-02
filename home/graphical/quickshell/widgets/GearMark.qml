pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Opens the control centre. Collapsed it is a solid block coloured by
// notification state; expanded it is that block, bare when idle and carrying
// the notification count when anything is waiting.
Rectangle {
    id: root

    required property bool expanded

    // the rail's own 0 to 1 travel, which every width here follows
    required property real reveal

    property bool active: false

    // set by the bar's corner hover zone, which is what actually opens the
    // panel; the mark only draws the state
    property bool hovered: false

    readonly property bool has: Notifications.count > 0
    readonly property bool urgent: Notifications.hasUrgent

    // red for urgent, yellow when anything is waiting, otherwise the same grey
    // an empty slot would draw
    readonly property color hue: urgent ? Theme.red : has ? Theme.yellow : Theme.surface1

    implicitWidth: Theme.sliver + (32 - Theme.sliver) * reveal
    implicitHeight: 32
    radius: 0
    color: "transparent"

    // one value for both hover and open, so the state fades in on hover and is
    // simply held while the modal is up rather than swapping to a second style
    // gated on expanded: the hover target spans the full rail width even while
    // collapsed, so without this the sliver would light up in passing
    // not readonly: Behavior writes to it, and a Behavior on a readonly
    // property is an invalid assignment
    property real highlight: expanded && (active || hovered) ? 1 : 0

    Behavior on highlight {
        NumberAnimation {
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuad
        }
    }

    // Solid block carrying the count. Height is constant, matching the
    // workspace marks: only the width animates on expand.
    Rectangle {
        anchors.centerIn: parent

        // Widens for two and three digit counts, eased so a count gaining a
        // digit grows the block rather than snapping it. Not readonly: the
        // Behavior writes to it.
        property real expandedWidth: Math.max(Theme.iconSize + 3, label.implicitWidth + 10)

        Behavior on expandedWidth {
            Morph {}
        }

        width: Theme.sliver + (expandedWidth - Theme.sliver) * root.reveal
        height: Theme.iconSize + 3

        // Always solid: the block is the button, and the count is drawn in
        // crust on top of it, so it needs a ground in every state. Hover
        // brightens it, dropped instantly on collapse so a fading blue over the
        // state colour never blends through blue grey.
        color: Qt.tint(root.hue, Qt.alpha(Theme.text, 0.25 * (root.expanded ? root.highlight : 0)))
    }

    // The count sits directly on the block, which is already the right size
    // and colour.
    Text {
        id: label

        anchors.centerIn: parent

        // empty when nothing is waiting: a bare block reads as the idle state
        text: root.has ? Notifications.count : ""
        font.family: Theme.font
        font.pixelSize: 10
        font.bold: true
        color: Theme.crust

        // fades with the rail; always present, reading 0 when nothing waits
        opacity: root.reveal
        visible: opacity > 0
    }

    // The hover zone that opens the panel is not here: it spans the whole top
    // corner of the rail, which only the bar knows the geometry of.
}
