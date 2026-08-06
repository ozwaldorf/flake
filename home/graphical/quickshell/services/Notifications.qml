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
    property bool starting: true

    Timer {
        running: true
        interval: 10000
        onTriggered: root.starting = false
    }

    readonly property bool toastsSuppressed: toastHolders > 0 || starting

    function holdToasts(on) {
        toastHolders = Math.max(0, toastHolders + (on ? 1 : -1));
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

    function remove(id) {
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).id === id) {
                history.remove(i);
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
        history.clear();
        toasts.clear();
        refreshUrgent();
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
                expireTimeout: notif.expireTimeout,
                notification: notif
            };

            root.history.insert(0, entry);
            // while the panel is open the entry is already visible in its
            // history list, so a toast would just duplicate it
            if (!root.toastsSuppressed)
                root.toasts.insert(0, entry);
            root.refreshUrgent();
        }
    }
}
