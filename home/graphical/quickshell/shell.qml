import QtQuick
import Quickshell
import "modals"
import "services"

ShellRoot {
    // services do not import the config root, so the theme's timings are
    // pushed in from here rather than pulled up from the service
    Component.onCompleted: {
        SysMeters.intervalActive = Theme.meterIntervalActive;
        SysMeters.intervalIdle = Theme.meterInterval;
    }

    // one bar and one modal stack per monitor; Quickshell.screens is reactive,
    // so hotplugging a display creates and destroys them automatically
    Variants {
        model: Quickshell.screens

        Scope {
            id: scope

            required property var modelData

            // The bar hugs the outward facing edge of the arrangement: left on
            // the leftmost screen, right on the rightmost. With a single screen
            // this is always the left edge.
            readonly property bool anchorRight: {
                let rightmost = null;
                for (const s of Quickshell.screens) {
                    if (!rightmost || s.x > rightmost.x)
                        rightmost = s;
                }
                return rightmost !== null && Quickshell.screens.length > 1 && modelData.name === rightmost.name;
            }

            property string openModal: ""

            // set by clicking a mark: pins the modal so it survives the pointer
            // leaving, until clicked again or another mark takes over
            property bool pinned: false

            // whichever mark the pointer is over, and whether a modal has it
            property string hoveredMark: ""
            property bool modalHovered: false

            function toggle(name) {
                if (openModal === name && pinned) {
                    openModal = "";
                    pinned = false;
                } else {
                    openModal = name;
                    pinned = true;
                }
            }

            // Opening waits out a dwell so crossing a mark on the way to another
            // does not flash it open. Closing waits longer so the pointer can
            // travel the gap from mark to panel.
            Timer {
                id: openTimer
                interval: 180
                onTriggered: {
                    if (scope.hoveredMark !== "") {
                        scope.openModal = scope.hoveredMark;
                        graceTimer.restart();
                    }
                }
            }

            // Opening a modal resizes the rail and the marks under a stationary
            // pointer, and Qt re-evaluates hover against the new geometry. That
            // emits a spurious unhover, so ignore close requests until the
            // layout has settled.
            Timer {
                id: graceTimer
                interval: Theme.morphDuration + 120
            }

            Timer {
                id: closeTimer
                interval: 320
                onTriggered: {
                    if (scope.pinned || scope.modalHovered || scope.hoveredMark !== "")
                        return;
                    if (graceTimer.running) {
                        // layout still settling; re-arm rather than dismissing
                        closeTimer.restart();
                        return;
                    }
                    scope.openModal = "";
                }
            }

            function evaluateHover() {
                if (hoveredMark !== "") {
                    closeTimer.stop();
                    // switching between marks while one is open is immediate
                    if (openModal !== "" && openModal !== hoveredMark) {
                        openModal = hoveredMark;
                        pinned = false;
                        graceTimer.restart();
                    } else if (openModal === "") {
                        openTimer.restart();
                    }
                } else {
                    openTimer.stop();
                    if (!pinned && !modalHovered)
                        closeTimer.restart();
                }
            }

            onHoveredMarkChanged: evaluateHover()
            onModalHoveredChanged: {
                if (modalHovered)
                    closeTimer.stop();
                else if (!pinned && hoveredMark === "")
                    closeTimer.restart();
            }

            Bar {
                id: bar

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                modalOpen: scope.openModal !== ""
                settingsActive: scope.openModal === "settings"

                onSettingsToggled: scope.toggle("settings")
                onMarkHovered: name => scope.hoveredMark = name
            }

            ControlCenter {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.openModal === "settings"
                onDismissed: {
                    scope.openModal = "";
                    scope.pinned = false;
                }
                onHoverChanged: hovered => scope.modalHovered = hovered
            }

            Toasts {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                barExpanded: bar.expanded
            }

            // Opening the panel clears every toast outright rather than hiding
            // them: the same notifications are listed inside it, and critical
            // ones have no timeout so they would otherwise return on close.
            // Suppression then keeps new arrivals from duplicating the list.
            readonly property bool panelOpen: openModal === "settings"

            onPanelOpenChanged: {
                Notifications.holdToasts(panelOpen);
                if (panelOpen)
                    Notifications.dismissAllToasts();
            }
        }
    }
}
