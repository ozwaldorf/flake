import QtQuick
import Quickshell
import Quickshell.Io
import "modals"
import "services"
import "widgets"

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

    // `qs ipc call drawer open <name>` or `close`, for a keybind: opens
    // a drawer behind the rail on every screen.
    signal drawerRequested(string name)
    signal listRequested(string name)

    // a drawer opened or put away on one screen, by its output name
    signal drawerToggled(string name, string output)

    // a drawer put out, or none, on one screen or every one
    signal drawerSet(string name, string output)

    IpcHandler {
        target: "drawer"

        function open(name: string): void {
            shell.drawerRequested(name);
        }

        function close(): void {
            shell.drawerRequested("");
        }

        // The overview and the control centre together, as the hot corner
        // opens them, or both put away if the overview is already up.
        function overview(): void {
            if (Niri.overviewOpen) {
                Niri.closeOverview();
                shell.drawerSet("", "");
                return;
            }
            Niri.openOverview();
            shell.drawerSet("settings", Niri.focusedOutput());
        }

        // Opens a drawer on the focused screen, or closes it if it is the one
        // already out there, for a keybind.
        function toggle(name: string): void {
            shell.drawerToggled(name, Niri.focusedOutput());
        }

        // opens one of the control centre's lists by name, or none
        function list(name: string): void {
            shell.drawerRequested("settings");
            shell.listRequested(name);
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

            // Which drawer is open behind the rail, if any: "settings" for the
            // control centre, opened from the rail's top corner, or "info" for
            // the monitor and calendar, opened from its foot. Each opens on a
            // hover or a tap there, and closes when the pointer leaves the rail
            // and drawer, or on a tap on the rest of the rail.
            //
            // With the overview up the control centre waits for the overview
            // to close instead, so the pointer can travel out to it and the tap
            // that picks a window there is not spent on the drawer first.
            property string drawer: ""
            readonly property bool panelOpen: drawer === "settings"

            // The drawers are pages side by side in the order of their tabs,
            // each later one to the right: the value is the index of the page
            // in view. Switching with one already open slides between
            // them on the same spring as the rail; opening from
            // closed puts the page straight in place, since the desktop sliding
            // aside is reveal enough. Left where it was on close, so the page
            // is covered by the desktop coming back rather than vanishing.
            property string lastDrawer: ""

            readonly property var pages: ["settings", "info", "apps", "clipboard", "keys"]

            // Opened from a keybind and worked from the keyboard, so they stay
            // out until put away rather than closing as the pointer leaves.
            readonly property bool keyboardDrawer: keyboardHeld || drawer === "apps" || drawer === "clipboard" || drawer === "keys"

            // Reached by ctrl+tab, so held from the keyboard whatever the drawer,
            // until it is put away.
            property bool keyboardHeld: false

            function cycle(by) {
                keyboardHeld = true;
                drawer = pages[(pages.indexOf(drawer) + by + pages.length) % pages.length];
            }

            // How far a page sits across from view, by its place in the row. Laid
            // out left to right on either screen, matching the tabs.
            function pageOffset(name) {
                return (pages.indexOf(name) - pager.value) * (Theme.drawerWidth + Theme.railInset * 2);
            }

            onDrawerChanged: {
                if (drawer === "")
                    keyboardHeld = false;
                if (drawer !== "") {
                    pager.target = pages.indexOf(drawer);
                    if (lastDrawer === "") {
                        pager.stop();
                        pager.velocity = 0;
                        pager.value = pager.target;
                    }
                }
                lastDrawer = drawer;
            }

            Connections {
                target: shell

                function onDrawerRequested(name) {
                    scope.drawer = name;
                }

                function onDrawerToggled(name, output) {
                    if (output !== "" && scope.modelData.name !== output)
                        return;
                    scope.drawer = scope.drawer === name ? "" : name;
                }

                function onDrawerSet(name, output) {
                    if (output === "" || scope.modelData.name === output)
                        scope.drawer = name;
                }
            }

            readonly property bool cornerHovered: bar.cornerHovered
            readonly property bool bottomHovered: bar.bottomHovered

            // Opening waits out a short dwell so a pointer passing through on
            // its way somewhere else does not flash a drawer open.
            Timer {
                id: openTimer
                interval: 50
                onTriggered: {
                    if (scope.cornerHovered)
                        scope.drawer = "settings";
                    else if (scope.bottomHovered)
                        scope.drawer = "info";
                }
            }

            onCornerHoveredChanged: {
                if (cornerHovered && drawer !== "settings")
                    openTimer.restart();
            }

            onBottomHoveredChanged: {
                if (bottomHovered && drawer !== "info")
                    openTimer.restart();
            }

            property bool settingsHovered: false
            property bool infoHovered: false
            property bool tabsHovered: false
            readonly property bool pointerInside: bar.pointerInside || settingsHovered || infoHovered || tabsHovered

            // Closing waits a little, so brushing past the drawer's edge does
            // not throw it shut.
            Timer {
                id: closeTimer
                interval: Theme.exitDelay
                onTriggered: {
                    if (!scope.pointerInside && !scope.keyboardDrawer && !(scope.panelOpen && Niri.overviewOpen))
                        scope.drawer = "";
                }
            }

            onPointerInsideChanged: {
                if (pointerInside)
                    closeTimer.stop();
                else if (drawer !== "")
                    closeTimer.restart();
            }

            Connections {
                target: Niri

                function onOverviewOpenChanged() {
                    // the overview held the control centre open past the
                    // pointer leaving; with it gone, so is the drawer, unless
                    // the pointer is still on it
                    if (!Niri.overviewOpen && scope.panelOpen && !scope.pointerInside)
                        scope.drawer = "";
                }
            }

            // Named apart from the Wallpaper singleton it draws: modals and
            // services are imported into the same scope, and a shared name
            // resolves to the singleton, which is not creatable.
            WallpaperLayer {
                modelData: scope.modelData
                push: scope.anchorRight ? -bar.pushWidth : bar.pushWidth
            }

            // Not while the overview is up: the control centre is held open
            // beside it so the pointer can travel out to a window, and the tap
            // that picks one would be spent here instead.
            DismissCatcher {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                active: scope.drawer !== "" && !Niri.overviewOpen
                pushWidth: bar.pushWidth
                onDismissed: scope.drawer = ""
            }

            Bar {
                id: bar

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                panelOpen: scope.panelOpen
                drawerWidth: scope.drawer !== "" ? settings.drawerWidth : 0
                onCornerTapped: scope.drawer = "settings"
                onBottomTapped: scope.drawer = "info"
                onRailTapped: scope.drawer = ""
                onDrawerTapped: settings.openList("")
                onHotCornerEntered: {
                    Niri.openOverview();
                    scope.drawer = "settings";
                }

                // Kept in the bar's window rather than out in the scope: a
                // frame driven animation needs a window whose frames drive it.
                Spring {
                    id: pager
                }
            }

            ControlCenter {
                id: settings

                Connections {
                    target: shell

                    function onListRequested(name) {
                        settings.openList(name);
                    }
                }

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.panelOpen
                revealWidth: bar.pushWidth
                pageX: scope.pageOffset("settings")
                onHoverChanged: hovered => scope.settingsHovered = hovered
                grabsKeyboard: scope.keyboardHeld
                onCycleRequested: by => scope.cycle(by)
                onCloseRequested: scope.drawer = ""
            }

            InfoPanel {
                id: info

                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.drawer === "info"
                revealWidth: bar.pushWidth
                pageX: scope.pageOffset("info")
                onHoverChanged: hovered => scope.infoHovered = hovered
                grabsKeyboard: scope.keyboardHeld
                onCycleRequested: by => scope.cycle(by)
                onCloseRequested: scope.drawer = ""
            }

            Launcher {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.drawer === "apps"
                revealWidth: bar.pushWidth
                pageX: scope.pageOffset("apps")
                onCloseRequested: scope.drawer = ""
                onCycleRequested: by => scope.cycle(by)
            }

            ClipboardPanel {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.drawer === "clipboard"
                revealWidth: bar.pushWidth
                pageX: scope.pageOffset("clipboard")
                onCloseRequested: scope.drawer = ""
                onCycleRequested: by => scope.cycle(by)
            }

            KeysPanel {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.drawer === "keys"
                revealWidth: bar.pushWidth
                pageX: scope.pageOffset("keys")
                onCloseRequested: scope.drawer = ""
                onCycleRequested: by => scope.cycle(by)
            }

            // after the pages, so it stands over them
            DrawerTabs {
                modelData: scope.modelData
                anchorRight: scope.anchorRight
                shown: scope.drawer !== ""
                revealWidth: bar.pushWidth
                pages: scope.pages
                current: scope.drawer
                onPicked: name => scope.drawer = name
                onHoverChanged: hovered => scope.tabsHovered = hovered
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
