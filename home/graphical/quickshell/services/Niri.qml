pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Niri's workspaces, followed over its IPC event stream.
//
// Kept in a ListModel updated in place rather than a rebuilt array: a new array
// would recreate every delegate bound to it on each change and cut their
// animations short.
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""

    // wsId, idx, output, active, focused, urgent, windows; ordered by output and
    // then by index
    readonly property ListModel workspaces: ListModel {}

    // workspace, scrolling column and tile width of every open window, keyed by
    // window id; the column is null for floating windows
    property var windowInfo: ({})

    // focused window of every workspace, keyed by workspace id
    property var activeWindow: ({})

    // Where each output's view sits, keyed by output name: x is the view's
    // scroll across the active workspace's columns and y the active workspace
    // down the output, both from 0 at the first to 1 at the last
    property var views: ({})

    // Scroll offset of every workspace's view in logical pixels, keyed by
    // workspace id. Niri does not report it, so it is replayed here from the
    // focused column with niri's default rule: the view moves only as far as
    // it takes to bring the focused column fully on screen.
    property var scrollOffsets: ({})

    // whether the overview is up, on any output: niri has one for all of them
    property bool overviewOpen: false

    // layout gaps and struts from niri.nix, which the replay needs to match
    readonly property real gap: 10
    readonly property real strut: 10

    // the output holding the focused workspace, read at the moment asked
    function focusedOutput(): string {
        for (let i = 0; i < workspaces.count; i++) {
            const ws = workspaces.get(i);
            if (ws.focused)
                return ws.output;
        }
        return "";
    }

    function focusWorkspace(id: int): void {
        request({
            Action: {
                FocusWorkspace: {
                    reference: {
                        Id: id
                    }
                }
            }
        });
    }

    function closeOverview(): void {
        request({
            Action: {
                CloseOverview: {}
            }
        });
    }

    function openOverview(): void {
        request({
            Action: {
                OpenOverview: {}
            }
        });
    }

    function request(body: var): void {
        const line = JSON.stringify(body) + "\n";
        const socket = requestSocket.createObject(root, {
            line
        });
        socket.connected = true;
    }

    Component {
        id: requestSocket

        Socket {
            id: socket

            property string line

            path: root.socketPath

            onConnectedChanged: {
                if (connected) {
                    write(line);
                    flush();
                } else {
                    destroy();
                }
            }

            // the reply is only an acknowledgement
            parser: SplitParser {
                onRead: Qt.callLater(() => socket.connected = false)
            }

            onError: destroy()
        }
    }

    Socket {
        id: events

        path: root.socketPath
        connected: root.socketPath !== ""

        onConnectedChanged: {
            if (connected) {
                write('"EventStream"\n');
                flush();
            } else {
                reconnect.start();
            }
        }

        onError: reconnect.start()

        parser: SplitParser {
            onRead: line => {
                let event;
                try {
                    event = JSON.parse(line);
                } catch (e) {
                    return;
                }
                root.handle(event);
            }
        }
    }

    // niri restarting drops the stream; pick it back up once it is listening
    Timer {
        id: reconnect

        interval: 1000
        onTriggered: {
            events.connected = false;
            events.connected = root.socketPath !== "";
        }
    }

    function handle(event: var): void {
        if (event.OverviewOpenedOrClosed) {
            overviewOpen = event.OverviewOpenedOrClosed.is_open;
        } else if (event.WorkspacesChanged) {
            syncWorkspaces(event.WorkspacesChanged.workspaces);
        } else if (event.WorkspaceActivated) {
            const {
                id,
                focused
            } = event.WorkspaceActivated;
            const output = find(id)?.output;
            for (let i = 0; i < workspaces.count; i++) {
                const ws = workspaces.get(i);
                if (ws.output === output)
                    workspaces.setProperty(i, "active", ws.wsId === id);
                if (focused)
                    workspaces.setProperty(i, "focused", ws.wsId === id);
            }
            refresh();
        } else if (event.WorkspaceActiveWindowChanged) {
            const change = event.WorkspaceActiveWindowChanged;
            activeWindow[change.workspace_id] = change.active_window_id;
            refresh();
        } else if (event.WorkspaceUrgencyChanged) {
            const i = indexOf(event.WorkspaceUrgencyChanged.id);
            if (i >= 0)
                workspaces.setProperty(i, "urgent", event.WorkspaceUrgencyChanged.urgent);
        } else if (event.WindowsChanged) {
            const map = {};
            for (const w of event.WindowsChanged.windows)
                map[w.id] = info(w);
            windowInfo = map;
            refresh();
        } else if (event.WindowOpenedOrChanged) {
            const w = event.WindowOpenedOrChanged.window;
            windowInfo[w.id] = info(w);
            refresh();
        } else if (event.WindowClosed) {
            delete windowInfo[event.WindowClosed.id];
            refresh();
        } else if (event.WindowLayoutsChanged) {
            for (const [id, layout] of event.WindowLayoutsChanged.changes) {
                if (windowInfo[id])
                    windowInfo[id] = Object.assign(info({
                        layout
                    }), {
                        ws: windowInfo[id].ws
                    });
            }
            refresh();
        }
    }

    function find(id: int): var {
        const i = indexOf(id);
        return i >= 0 ? workspaces.get(i) : null;
    }

    function indexOf(id: int): int {
        for (let i = 0; i < workspaces.count; i++) {
            if (workspaces.get(i).wsId === id)
                return i;
        }
        return -1;
    }

    function info(w: var): var {
        return {
            ws: w.workspace_id,
            col: w.layout?.pos_in_scrolling_layout?.[0] ?? null,
            width: w.layout?.tile_size?.[0] ?? 0
        };
    }

    function refresh(): void {
        const counts = {};
        // column widths of every workspace, 1-based as niri numbers them
        const columns = {};
        for (const id in windowInfo) {
            const {
                ws,
                col,
                width
            } = windowInfo[id];
            if (ws === null)
                continue;
            counts[ws] = (counts[ws] ?? 0) + 1;
            if (col !== null) {
                if (!columns[ws])
                    columns[ws] = [];
                columns[ws][col] = Math.max(columns[ws][col] ?? 0, width);
            }
        }

        const outputs = {};
        for (let i = 0; i < workspaces.count; i++) {
            const ws = workspaces.get(i);
            workspaces.setProperty(i, "windows", counts[ws.wsId] ?? 0);
            if (!outputs[ws.output])
                outputs[ws.output] = [];
            outputs[ws.output].push(ws);
        }

        // Reassigned whole so bindings on it are notified
        const next = {};
        for (const output in outputs) {
            const list = outputs[output];
            const pos = list.findIndex(ws => ws.active);
            const active = list[pos];
            const screen = Quickshell.screens.find(s => s.name === output);
            const widths = columns[active?.wsId] ?? [];
            next[output] = {
                x: active && screen ? scrollFraction(active.wsId, widths, screen.width - 2 * strut) : 0,
                y: list.length > 1 && pos >= 0 ? pos / (list.length - 1) : 0
            };
        }
        views = next;
    }

    // Advances the workspace's replayed scroll to the focused column and
    // returns it as a fraction of how far the view can scroll. A floating
    // window has no column, so focusing one leaves the view where it was.
    function scrollFraction(wsId: int, widths: var, viewWidth: real): real {
        const starts = [];
        let x = gap;
        for (let c = 1; c < widths.length; c++) {
            starts[c] = x;
            x += (widths[c] ?? 0) + gap;
        }
        const range = Math.max(0, x - viewWidth);

        let offset = scrollOffsets[wsId] ?? 0;
        const col = windowInfo[activeWindow[wsId]]?.col;
        if (col != null && starts[col] !== undefined) {
            const left = starts[col] - gap;
            const right = starts[col] + widths[col] + gap;
            if (left < offset || right - left > viewWidth)
                offset = left;
            else if (right > offset + viewWidth)
                offset = right - viewWidth;
        }
        offset = Math.min(Math.max(offset, 0), range);
        scrollOffsets[wsId] = offset;

        return range > 0 ? offset / range : 0;
    }

    // Moves surviving rows into place rather than replacing them, so a
    // workspace keeps its delegate for as long as it exists.
    function syncWorkspaces(list: var): void {
        const sorted = list.slice().sort((a, b) => (a.output ?? "").localeCompare(b.output ?? "") || a.idx - b.idx);
        const ids = new Set(sorted.map(ws => ws.id));

        for (let i = workspaces.count - 1; i >= 0; i--) {
            if (!ids.has(workspaces.get(i).wsId))
                workspaces.remove(i);
        }

        sorted.forEach((ws, target) => {
            const row = {
                wsId: ws.id,
                idx: ws.idx,
                output: ws.output ?? "",
                active: ws.is_active,
                focused: ws.is_focused,
                urgent: ws.is_urgent,
                windows: 0
            };
            activeWindow[ws.id] = ws.active_window_id;
            const current = indexOf(ws.id);
            if (current < 0) {
                workspaces.insert(target, row);
                return;
            }
            if (current !== target)
                workspaces.move(current, target, 1);
            for (const key of ["idx", "output", "active", "focused", "urgent"])
                workspaces.setProperty(target, key, row[key]);
        });

        refresh();
    }
}
