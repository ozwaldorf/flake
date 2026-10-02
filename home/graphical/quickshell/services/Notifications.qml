pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns org.freedesktop.Notifications. Only one process can hold the name, so
// no other notification daemon can be running.
Singleton {
    id: root

    // full history, newest first
    property ListModel history: ListModel {}
    // currently visible toasts
    property ListModel toasts: ListModel {}

    readonly property int count: history.count

    // Every entry is a card in each screen's panel, so the oldest are dropped
    // past this rather than left to accumulate for the life of the session.
    readonly property int historyLimit: 50
    property bool hasUrgent: false

    // Suppressed while a control centre is open: new notifications still land
    // in history, they just do not pop a toast that duplicates the panel.
    //
    // Counted rather than a flag because there is one panel per monitor, and
    // closing one must not unsuppress while another is still open.
    property int toastHolders: 0

    // Held for a moment after the shell starts as well. Anything already
    // queued arrives the instant the server takes the name, and a shell that
    // has just restarted popping a stack of notifications from before it was
    // running is noise: they are in the history either way.
    //
    // Long enough for that queue to land and no longer. The hold is re-armed
    // whenever this singleton is rebuilt, which a config reload does, so a
    // generous window is one where every toast is silently swallowed for that
    // long after any edit to the shell.
    property bool starting: true

    Timer {
        running: root.starting
        interval: 1000
        onTriggered: root.starting = false
    }

    readonly property bool toastsSuppressed: toastHolders > 0 || starting

    // Clamped at both ends: there is one panel per screen, so the count cannot
    // legitimately pass that. A raise that loses its release, from a panel torn
    // down while open, would otherwise suppress every toast for good.
    function holdToasts(on) {
        toastHolders = Math.max(0, Math.min(Quickshell.screens.length, toastHolders + (on ? 1 : -1)));
    }

    function refreshUrgent() {
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).urgency === NotificationUrgency.Critical) {
                root.hasUrgent = true;
                return;
            }
        }
        root.hasUrgent = false;
    }

    function dismiss(id) {
        for (let i = 0; i < toasts.count; i++) {
            if (toasts.get(i).id === id) {
                toasts.remove(i);
                break;
            }
        }
    }

    // id -> the live Notification behind an entry, for its actions. Held apart
    // from the models rather than as a role in them: a ListModel fixes its
    // roles from the first entry it is given, and one of the shell's own
    // notices, which has no object, would drop the role for every entry after.
    //
    // Replaced rather than mutated, so the cards reading actions through it
    // see an entry go.
    property var objects: ({})

    function forget(id) {
        if (!(id in objects))
            return;
        const next = Object.assign({}, objects);
        delete next[id];
        objects = next;
    }

    // An app can close its own notification while the entry is still listed.
    // The object is gone from then on, so the entry stops offering actions on,
    // or releasing, a notification that no longer exists.
    function detach(id) {
        forget(id);
    }

    // Tracked notifications stay alive on the server until released, so an
    // entry leaving history releases the object behind it as well.
    function release(i) {
        const id = history.get(i).id;
        objects[id]?.dismiss();
        forget(id);
        history.remove(i);
    }

    function remove(id) {
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).id === id) {
                release(i);
                break;
            }
        }
        dismiss(id);
        refreshUrgent();
    }

    // Drops every visible toast without touching history, including critical
    // ones that have no timeout. Used when the control centre opens, since the
    // same notifications are listed there.
    function dismissAllToasts() {
        toasts.clear();
    }

    function clear() {
        while (history.count > 0)
            release(history.count - 1);
        toasts.clear();
        refreshUrgent();
    }

    // Files an entry into history, and pops it as a toast unless something is
    // holding toasts back.
    function add(entry, toast) {
        history.insert(0, entry);
        while (history.count > historyLimit)
            release(history.count - 1);
        if (toast)
            toasts.insert(0, entry);
        refreshUrgent();
    }

    // The shell's own notices, such as a config reload, shown like any other
    // notification but raised from here rather than over the bus.
    //
    // Exempt from the startup hold, which is there for a backlog arriving the
    // moment the server takes the name: a reload notice lands inside exactly
    // that window, and is the one thing in it worth seeing. Still held while a
    // panel is open, where the history already shows it.
    property int nextLocalId: -1

    function post(summary, body, critical, timeout) {
        add({
            id: nextLocalId--,
            appName: "quickshell",
            summary: summary,
            body: body,
            image: "",
            appIcon: "",
            urgency: critical ? NotificationUrgency.Critical : NotificationUrgency.Low,
            expireTimeout: timeout ?? -1
        }, toastHolders === 0);
    }

    // Drops <img> tags from a body before it ever reaches a Text.
    //
    // The spec lists <img> among the body's markup, but Qt lays one out at the
    // image's natural size, which no maximumLineCount bounds: a card carrying
    // one grows past the blur region computed for it and spills over the
    // desktop. It would also fetch the URL, so a notification body could phone
    // home. GitHub sends exactly this. StyledText is not a way out; it renders
    // <img> too.
    function stripImages(body) {
        return body.replace(/<img\b[^>]*>/gi, "").trim();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        inlineReplySupported: true

        onNotification: notif => {
            // keep it alive past the callback so actions stay invokable
            notif.tracked = true;

            const entry = {
                id: notif.id,
                appName: notif.appName || "system",
                summary: notif.summary,
                body: root.stripImages(notif.body),
                image: notif.image,
                appIcon: notif.appIcon,
                urgency: notif.urgency,
                // seconds as the app requested it; -1 means it has no
                // preference and 0 means it should never expire
                expireTimeout: notif.expireTimeout
            };

            const next = Object.assign({}, root.objects);
            next[notif.id] = notif;
            root.objects = next;

            // An app can close its own notification while the entry is still
            // listed. The object is gone from then on, so the entry stops
            // carrying it rather than offering actions on, or releasing, a
            // notification that no longer exists.
            notif.closed.connect(() => root.detach(notif.id));

            // while the panel is open the entry is already visible in its
            // history list, so a toast would just duplicate it
            root.add(entry, !root.toastsSuppressed);
        }
    }
}
