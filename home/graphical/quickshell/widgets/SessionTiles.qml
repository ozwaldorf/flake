pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Power beside the brightness, with the power actions opening over them.
// Power takes a third, being a tile with nothing to read on it, and leads the
// row from the rail's side; the brightness takes the rest of the width for its
// track.
TileGroup {
    id: root

    // Filled from the edge the rail is on, so power leads the row from
    // whichever side the panel opened from.
    property bool anchorRight: false

    // one column of the panel's three, so this row lines up with the rest
    readonly property real third: Theme.third(width)

    tileRow.layoutDirection: anchorRight ? Qt.RightToLeft : Qt.LeftToRight

    // one height across the row, whichever of the two is taller
    readonly property real rowHeight: Math.max(power.implicitHeight, brightness.visible ? brightness.implicitHeight : 0)

    // A refusal is worth showing while the list that caused it is up, but not
    // held against the next time the tile is opened.
    onOpenChanged: {
        if (open === "")
            Power.error = "";
    }

    // what the tray entries below size themselves against
    readonly property real tileHeight: power.implicitHeight

    PowerTile {
        id: power

        // the whole row when there is no backlight to share it with
        width: brightness.visible ? root.third : root.width
        height: root.rowHeight
        host: root.host

        listName: "power"
        expanded: root.open === "power"

        onListToggled: root.toggle("power")
    }

    BrightnessCard {
        id: brightness

        width: root.width - root.third - root.tileRow.spacing
        height: root.rowHeight
        host: root.host
    }

    lists: [
        PowerList {
            objectName: "power"
        }
    ]
}
