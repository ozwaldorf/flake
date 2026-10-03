pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The compositor's keybinds, as the rebuild serialised them out of the niri
// config: [{ key, label, group }], already in the order they are listed.
Singleton {
    id: root

    property var binds: []

    function filter(query) {
        const q = query.trim().toLowerCase();
        return q === "" ? binds : binds.filter(b => b.label.toLowerCase().includes(q) || b.key.toLowerCase().includes(q) || b.group.toLowerCase().includes(q));
    }

    FileView {
        path: Quickshell.env("QUICKSHELL_KEYBINDS") ?? ""
        printErrors: false

        onLoaded: {
            try {
                root.binds = JSON.parse(text());
            } catch (e) {
                root.binds = [];
            }
        }
    }
}
