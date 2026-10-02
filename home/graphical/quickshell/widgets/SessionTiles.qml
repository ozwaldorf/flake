pragma ComponentBehavior: Bound

import QtQuick
import "../services"

// Power and the screen recorder side by side, with the power actions opening
// underneath. Only one of the two has anything to disclose, so the join is
// always on the power tile's side.
TileGroup {
    id: root

    // Filled from the edge the rail is on, so power leads the row from
    // whichever side the panel opened from.
    property bool anchorRight: false

    readonly property real cell: (width - tileRow.spacing) / 2

    tileRow.layoutDirection: anchorRight ? Qt.RightToLeft : Qt.LeftToRight

    joinLeft: anchorRight ? width - cell : 0
    joinRight: anchorRight ? width : cell

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

        width: root.cell
        host: root.host

        expanded: root.open === "power"
        joined: root.joined

        onListToggled: root.toggle("power")
    }

    RecorderTile {
        width: root.cell
        host: root.host
    }

    lists: [
        PowerList {
            objectName: "power"
        }
    ]
}
