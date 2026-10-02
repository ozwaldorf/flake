pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default sink and source, and the devices available to switch between.
// Everything here is event driven off Pipewire; the widgets never enumerate
// nodes themselves.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // Keeps the defaults bound so their volume and mute state track without
    // polling, and the listed devices bound so they carry a description rather
    // than showing up unnamed in the picker.
    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.sinks).concat(root.sources)
    }

    // Real devices only: streams are individual applications playing through a
    // sink, not something you can make the default. Re-collected whenever the
    // node list changes, which collect reads, or Pipewire finishes connecting.
    readonly property var sinks: Pipewire.ready ? collect(true) : []
    readonly property var sources: Pipewire.ready ? collect(false) : []

    function collect(wantSink) {
        const out = [];
        for (const n of Pipewire.nodes.values) {
            if (n.isStream || !n.audio)
                continue;
            if (n.isSink !== wantSink)
                continue;
            out.push(n);
        }
        out.sort((a, b) => label(a).localeCompare(label(b)));
        return out;
    }

    // Nodes carry a human name, a short nickname and an internal one. The
    // description is what every other mixer shows; the node name is a device
    // path and only worth falling back to.
    function label(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "Unknown device";
    }

    function setVolume(node, level) {
        if (!node?.audio)
            return;
        node.audio.volume = Math.max(0, Math.min(1, level));
    }

    function toggleMuted(node) {
        if (!node?.audio)
            return;
        node.audio.muted = !node.audio.muted;
    }

    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Switching is per node identity rather than by name: two cards can report
    // the same description, and the id is what Pipewire actually routes on.
    function isDefault(node, wantSink) {
        const current = wantSink ? sink : source;
        return current !== null && node !== null && current.id === node.id;
    }
}
