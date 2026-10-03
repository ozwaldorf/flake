pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, kept by cliphist and read back here. Listed fresh each
// time the drawer opens rather than watched: the store is only ever looked at
// from there.
//
// Images are decoded once into the cache, so the list can show them rather
// than cliphist's one line summary.
Singleton {
    id: root

    // newest first: { id, line, text, image }, image being { ext, size } or
    // null for text
    property var entries: []

    // Bumped once the thumbnails on disk have caught up with the list, and
    // carried in their URLs so an image asked for before its file landed is
    // asked for again rather than served from the failed load.
    property int thumbRevision: 0

    readonly property string thumbDir: `${Quickshell.cacheDir}/clipboard`

    function thumb(entry) {
        return entry.image && thumbRevision > 0 ? `file://${thumbDir}/${entry.id}.${entry.image.ext}?${thumbRevision}` : "";
    }

    function refresh() {
        list.running = true;
    }

    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]);
    }

    function remove(entry) {
        entries = entries.filter(e => e.id !== entry.id);
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.line]);
    }

    function wipe() {
        entries = [];
        Quickshell.execDetached(["cliphist", "wipe"]);
    }

    function filter(query) {
        const q = query.trim().toLowerCase();
        return q === "" ? entries : entries.filter(e => e.text.toLowerCase().includes(q));
    }

    Process {
        id: list

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    const id = line.slice(0, tab);
                    if (tab < 0 || !/^\d+$/.test(id))
                        continue;
                    const preview = line.slice(tab + 1);
                    const binary = /^\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]$/.exec(preview);
                    parsed.push({
                        id: id,
                        line: line,
                        text: binary ? `${binary[2].toUpperCase()} ${binary[3]}, ${binary[1]}` : preview,
                        image: binary && /^(png|jpe?g|gif|webp|bmp)$/.test(binary[2]) ? {
                            ext: binary[2]
                        } : null
                    });
                }
                root.entries = parsed;

                const images = parsed.filter(e => e.image).slice(0, 60).map(e => `${e.id}.${e.image.ext}`);
                if (images.length > 0) {
                    thumbs.command = ["sh", "-c", 'dir=$1; shift; mkdir -p "$dir"; for f; do [ -s "$dir/$f" ] || cliphist decode "${f%%.*}" > "$dir/$f"; done', "sh", root.thumbDir, ...images];
                    thumbs.running = true;
                }
            }
        }
    }

    Process {
        id: thumbs

        onExited: root.thumbRevision++
    }
}
