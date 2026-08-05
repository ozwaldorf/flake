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
    property bool active: false

    signal hoverChanged(bool hovered)

    readonly property bool has: Notifications.count > 0
    readonly property bool urgent: Notifications.hasUrgent

    // red for urgent, yellow when anything is waiting, otherwise the same grey
    // an empty slot would draw
    readonly property color hue: urgent ? Theme.red : has ? Theme.yellow : Theme.surface1

    implicitWidth: expanded ? 32 : Theme.sliver
    implicitHeight: 32
    radius: 0
    color: "transparent"

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    // one value for both hover and open, so the state fades in on hover and is
    // simply held while the modal is up rather than swapping to a second style
    // gated on expanded: the hover target spans the full rail width even while
    // collapsed, so without this the sliver would light up in passing
    // not readonly: Behavior writes to it, and a Behavior on a readonly
    // property is an invalid assignment
    property real highlight: expanded && (active || hover.hovered) ? 1 : 0

    Behavior on highlight {
        NumberAnimation {
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuad
        }
    }

    // 1 expanded, 0 collapsed, on the same clock as the geometry so the fill
    // colour arrives with the shape rather than ahead of it
    property real reveal: expanded ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    // Solid block carrying the count. Height is constant, matching the
    // workspace marks: only the width animates on expand.
    Rectangle {
        anchors.centerIn: parent

        // Bound to target values and animated once, exactly like a workspace
        // mark. Binding to parent.width instead would inherit the root's
        // in-flight tween and then re-animate from it, which snaps midway.
        readonly property real collapsedWidth: Theme.sliver
        // widens for two and three digit counts
        readonly property real expandedWidth: Math.max(Theme.iconSize + 3, label.implicitWidth + 10)

        width: root.expanded ? expandedWidth : collapsedWidth
        height: Theme.iconSize + 3

        Behavior on width {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

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

    // fixed size target so expanding never moves it under a stationary pointer
    Item {
        anchors.centerIn: parent
        width: Theme.rail
        height: parent.height

        // The panel opens on hover alone, so the mark is a target to reach
        // rather than a button: no tap handler, and the default cursor since
        // there is nothing to click.
        HoverHandler {
            id: hover
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }
}
