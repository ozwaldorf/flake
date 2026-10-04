pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../widgets"
import "../services"

// The app launcher: installed apps ranked by match and use, a sum worked out
// in place, and whatever was typed as a shell command to fall back on.
SearchPanel {
    id: root

    placeholder: "Search apps, calculate, run"
    glyph: Theme.iconSearch
    hints: "enter launch    tab next    esc close"
    results: live ? Apps.search(query) : []

    // Rescanned per opening so a switch or a new alias shows without a reload
    onShownChanged: if (shown)
        Apps.scanCommands()

    onActivated: result => {
        Apps.activate(result);
        root.closeRequested();
    }

    delegate: ResultRow {
        id: row

        required property var modelData
        required property int index

        readonly property bool app: modelData.kind === "app"
        readonly property bool calc: modelData.kind === "calc"

        current: ListView.isCurrentItem
        icon: app ? modelData.entry.icon : ""
        glyph: app ? Theme.iconApp : calc ? Theme.iconCalc : modelData.kind === "term" ? Theme.iconTerminal : Theme.iconRun
        glyphColor: app ? Theme.overlay1 : calc ? Theme.yellow : modelData.kind === "term" ? Theme.green : Theme.teal
        title: app ? modelData.entry.name : modelData.title
        detail: app ? (modelData.entry.genericName || modelData.entry.comment) : modelData.detail
        hint: calc ? "copy" : app ? "launch" : "run"

        onEntered: root.select(index)
        onTapped: root.activated(modelData)
    }
}
