pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Session power, disclosing the actions rather than doing anything itself.
// There is no state to switch here, so the puck is a mark rather than a
// button and the whole tile opens the list.
ToggleTile {
    id: root

    label: "Power"
    switchable: false

    // The puck follows the list rather than a switch, so the tile reads as
    // open the same way the others do.
    on: expanded

    status: {
        if (Power.error !== "")
            return Power.error;
        if (Power.pending !== "")
            return Power.label(Power.pending) + "...";
        return "";
    }

    warn: Power.error !== ""

    // Red rather than the usual blue: what is behind this tile ends the
    // session, and the colour is the only warning the closed tile carries.
    puckFill: expanded ? Theme.red : Theme.surface1

    glyph: PowerGlyph {
        anchors.centerIn: parent
        fill: root.expanded ? Theme.crust : Theme.overlay1
    }
}
