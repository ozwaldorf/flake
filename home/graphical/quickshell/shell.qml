import QtQuick
import Quickshell
import Quickshell.Io
import "modals"
import "services"

ShellRoot {
    id: shell

    // Raised over every screen while the session is idle. Held out here rather
    // than per screen so one call covers the whole desktop.
    property bool veiled: false

    // `qs ipc call wallpaper next|set <path>`, driven by the keybind.
    IpcHandler {
        target: "wallpaper"

        // Pulls a new one from Commons. Returns immediately: the fetch is a
        // network round trip and the caller is a keybind.
        function next(): void {
            Wallpaper.next();
        }

        function set(path: string): void {
            Wallpaper.setWallpaper(path);
        }

        function current(): string {
            return Wallpaper.current;
        }
    }

    // `qs ipc call veil raise|lower|toggle`, driven by the idle watcher.
    //
    // Deliberately not named show/hide: `qs ipc` parses those as its own
    // --show subcommand and prints the handler's metadata instead of calling.
    IpcHandler {
        target: "veil"

        function raise(): void {
            shell.veiled = true;
        }

        function lower(): void {
            shell.veiled = false;
        }

        function toggle(): void {
            shell.veiled = !shell.veiled;
        }
    }

    // `qs ipc call recorder toggle`, driven by the keybind.
    IpcHandler {
        target: "recorder"

        function toggle(): void {
            Recorder.toggle();
        }
    }

    // Reload results as ordinary notifications rather than Quickshell's own
    // popup. A success is brief and low, since it follows every save; a
    // failure stays until dismissed, since the config that is still running
    // is the old one and the error is what says why.
    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
            Notifications.post("Configuration reloaded", "", false, 2);
        }

        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup();
            // the body is read as markup, and an error quotes code
            Notifications.post("Configuration failed to load", errorString.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"), true, 0);
        }
    }

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

            property bool panelOpen: false

            // whether the pointer is on the rail's corner zone, or on the panel
            readonly property bool cornerHovered: bar.cornerHovered
            property bool panelHovered: false

            // Opening waits out a short dwell so a pointer passing through the
            // corner on its way somewhere else does not flash the panel open.
            // Closing waits longer so the pointer can travel the gap from the
            // zone to the panel.
            Timer {
                id: openTimer
                interval: 50
                onTriggered: {
                    if (scope.cornerHovered) {
                        scope.panelOpen = true;
                        graceTimer.restart();
                    }
                }
            }

            // Opening the panel resizes the rail under a stationary pointer,
            // and Qt re-evaluates hover against the new geometry. That emits a
            // spurious unhover, so ignore close requests until the layout has
            // settled.
            Timer {
                id: graceTimer
                interval: Theme.settleDelay
            }

            Timer {
                id: closeTimer
                interval: 320
                onTriggered: {
                    if (scope.panelHovered || scope.cornerHovered)
                        return;
                    if (graceTimer.running) {
                        // layout still settling; re-arm rather than dismissing
                        closeTimer.restart();
                        return;
                    }
                    scope.panelOpen = false;
                }
            }

            onCornerHoveredChanged: {
                if (cornerHovered) {
                    closeTimer.stop();
                    if (!panelOpen)
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    if (!panelHovered)
                        closeTimer.restart();
                }
            }

            onPanelHoveredChanged: {
                if (panelHovered)
                    closeTimer.stop();
                else if (!cornerHovered)
                    closeTimer.restart();
            }

            // Named apart from the Wallpaper singleton it draws: modals and
            // services are imported into the same scope, and a shared name
            // resolves to the singleton, which is not creatable.
            WallpaperLayer {
                modelData: scope.modelData
                push: scope.anchorRight ? -bar.railWidth : bar.railWidth
            }

            Bar {
                id: bar

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                panelOpen: scope.panelOpen
            }

            ControlCenter {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.panelOpen
                onHoverChanged: hovered => scope.panelHovered = hovered
            }

            Toasts {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                barReveal: bar.reveal
            }

            Veil {
                modelData: scope.modelData
                shown: shell.veiled
            }

            // Opening the panel clears every toast outright rather than hiding
            // them: the same notifications are listed inside it, and critical
            // ones have no timeout so they would otherwise return on close.
            // Suppression then keeps new arrivals from duplicating the list.
            onPanelOpenChanged: {
                Notifications.holdToasts(panelOpen);
                if (panelOpen)
                    Notifications.dismissAllToasts();
            }

            // Unplugging a monitor with its panel open destroys this scope with
            // the hold still raised, and nothing else would release it.
            Component.onDestruction: {
                if (panelOpen)
                    Notifications.holdToasts(false);
            }
        }
    }
}
