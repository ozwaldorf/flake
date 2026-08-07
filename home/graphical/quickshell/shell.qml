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

            // whichever mark the pointer is over, and whether a modal has it
            property string hoveredMark: ""
            property bool modalHovered: false

            // Opening waits out a short dwell so a pointer passing through the
            // corner on its way somewhere else does not flash the panel open.
            // Kept brief: there is only the one zone to cross now, so it is
            // guarding against a passing pointer rather than a mark being
            // crossed on the way to another. Closing waits longer so the
            // pointer can travel the gap from the zone to the panel.
            Timer {
                id: openTimer
                interval: 50
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
                    if (scope.modalHovered || scope.hoveredMark !== "")
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
                        graceTimer.restart();
                    } else if (openModal === "") {
                        openTimer.restart();
                    }
                } else {
                    openTimer.stop();
                    if (!modalHovered)
                        closeTimer.restart();
                }
            }

            onHoveredMarkChanged: evaluateHover()
            onModalHoveredChanged: {
                if (modalHovered)
                    closeTimer.stop();
                else if (hoveredMark === "")
                    closeTimer.restart();
            }

            Bar {
                id: bar

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                modalOpen: scope.openModal !== ""
                settingsActive: scope.openModal === "settings"

                onMarkHovered: name => scope.hoveredMark = name
            }

            ControlCenter {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.openModal === "settings"
                onDismissed: scope.openModal = ""
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

            // The hold lives in a singleton that survives a reload, and this
            // scope does not: a config reloaded with the panel open would
            // otherwise leave its hold behind with nothing left to release it,
            // and toasts would stay suppressed until the shell was restarted.
            Component.onDestruction: {
                if (panelOpen)
                    Notifications.holdToasts(false);
            }
        }
    }
}
