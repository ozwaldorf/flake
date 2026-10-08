pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../widgets"
import "../services"

// The app launcher: installed apps ranked by match and use, a sum worked out
// in place, whatever was typed as a shell command to fall back on, and
// programs from nixpkgs fetched and started on demand.
SearchPanel {
    id: root

    placeholder: "Search apps, calculate, run"
    glyph: Theme.iconSearch
    hints: "enter launch    tab next    right fill    esc close"
    results: live ? Apps.search(query) : []

    completion: current?.kind === "nix" ? (current.args ? `${current.bin} ${current.args}` : current.bin) : ""

    // Rescanned per opening so a switch or a new alias shows without a reload
    onShownChanged: if (shown)
        Apps.scanCommands()

    onQueryChanged: Nix.lookup(Apps.program(query.trim()))

    // A nix row stays open over its progress and closes once the program
    // starts; the row standing in for a lookup does nothing
    onActivated: result => {
        if (result.kind === "searching")
            return;
        Apps.activate(result);
        if (result.kind !== "nix")
            root.closeRequested();
    }

    Connections {
        target: Nix

        function onLaunched() {
            root.closeRequested();
        }
    }

    delegate: ResultRow {
        id: row

        required property var modelData
        required property int index

        readonly property bool app: modelData.kind === "app"
        readonly property bool calc: modelData.kind === "calc"
        readonly property bool nix: modelData.kind === "nix"
        readonly property bool searching: modelData.kind === "searching"
        readonly property bool fetching: nix && Nix.isTarget(modelData)
        readonly property bool failed: fetching && Nix.error !== ""

        current: ListView.isCurrentItem
        icon: app ? modelData.entry.icon : ""
        glyph: app ? Theme.iconApp : calc ? Theme.iconCalc : nix || searching ? Theme.iconNix : modelData.kind === "term" ? Theme.iconTerminal : Theme.iconRun
        glyphColor: app ? Theme.overlay1 : calc ? Theme.yellow : searching ? Theme.overlay0 : nix ? (failed ? Theme.red : Theme.sapphire) : modelData.kind === "term" ? Theme.green : Theme.teal
        title: app ? modelData.entry.name : nix ? modelData.bin : searching ? "Searching nixpkgs" : modelData.title
        detail: app ? (modelData.entry.genericName || modelData.entry.comment) : nix ? (fetching ? Nix.status : `nixpkgs#${modelData.attr}`) : searching ? "" : modelData.detail
        hint: calc ? "copy" : app ? "launch" : searching ? "" : nix ? (fetching && !failed ? "cancel" : failed ? "retry" : "fetch") : "run"
        loading: searching || (fetching && !failed)
        progress: searching ? -1 : Nix.progress

        onEntered: root.select(index)
        onTapped: root.activated(modelData)
    }
}
