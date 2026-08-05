pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import ".."
import "../widgets"
import "../services"

// Transient popups next to the rail. Critical notifications persist until
// dismissed; everything else times out on its own.
PanelWindow {
    id: root

    required property var modelData
    required property bool anchorRight

    // tracks the bar so toasts sit against the rail at whatever width it
    // currently is, rather than always clearing the full expanded width
    required property bool barExpanded

    // not readonly: the Behavior below writes to it
    property int railOffset: (barExpanded ? Theme.rail : Theme.sliver) + 8

    Behavior on railOffset {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    screen: modelData
    color: "transparent"
    exclusiveZone: 0
    visible: Notifications.toasts.count > 0

    anchors {
        left: !root.anchorRight
        right: root.anchorRight
        top: true
        bottom: true
    }

    implicitWidth: root.railOffset + Theme.modalWidth

    // click through everywhere except the toasts themselves
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        // collected by the window's blurRegion; each toast appends its own
        property list<Region> toastRegions

        x: root.anchorRight ? 0 : root.railOffset
        y: 12
        // same width as the control centre cards, so a notification looks
        // identical whether it is a toast or a history entry
        width: Theme.modalWidth
        spacing: Theme.spaceSm

        // surviving toasts slide up when one above them expires rather than
        // snapping to the new position
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 380
                easing.type: Easing.OutQuint
            }
        }

        Repeater {
            model: Notifications.toasts

            NotificationCard {
                id: toast

                required property var model

                width: parent.width
                anchorRight: root.anchorRight
                entry: model

                // fades in via the Column's add transition
                opacity: 0

                Component.onCompleted: {
                    opacity = 1;
                    stack.toastRegions.push(toastRegion);
                }

                Component.onDestruction: {
                    const i = stack.toastRegions.indexOf(toastRegion);
                    if (i >= 0)
                        stack.toastRegions.splice(i, 1);
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.OutQuint
                    }
                }

                // Blur switched at the halfway point of the fade rather than
                // scaled with it, so the region is not re-evaluated per frame.
                Region {
                    id: toastRegion

                    readonly property bool active: toast.opacity > 0.5

                    x: stack.x + toast.x
                    y: stack.y + toast.y
                    width: active ? toast.width : 0
                    height: active ? toast.height : 0
                    radius: toast.radius
                }

                // The app's own timeout wins when it asks for one. Per the
                // freedesktop spec a negative value means it has no preference
                // and zero means never expire, which criticals also get.
                readonly property real requested: toast.model.expireTimeout ?? -1
                readonly property bool persists: toast.critical || requested === 0
                readonly property int lifetime: requested > 0 ? requested * 1000 : Theme.toastTimeout

                Timer {
                    interval: toast.lifetime
                    running: !toast.persists
                    onTriggered: Notifications.dismiss(toast.model.id)
                }

                TapHandler {
                    onTapped: Notifications.dismiss(toast.model.id)
                }
            }
        }
    }

    // Union of the individual toasts rather than one box over the column: a
    // single region would blur the gaps between cards and square off their
    // rounded corners. Each delegate contributes its own region, so variable
    // card heights stay correct.
    BackgroundEffect.blurRegion: Region {
        regions: stack.toastRegions
    }
}
