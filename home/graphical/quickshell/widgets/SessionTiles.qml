pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Power and the screen recorder side by side, with the power actions opening
// underneath. Laid out like the connectivity pair, except only one of the two
// has anything to disclose, so the join is always on the power tile's side.
Column {
    id: root

    signal hoverChanged(bool hovered)

    // passed down to the cards, which each frost their own rectangle
    property var host: null

    // Which tile's list is showing: "power", or empty. Held by whatever lays
    // these out rather than here, so opening a list anywhere in the panel
    // closes whichever one was already out.
    property string open: ""

    signal requestOpen(string name)

    // Filled from the edge the rail is on, so power leads the row from
    // whichever side the panel opened from.
    property bool anchorRight: false

    width: parent ? parent.width : 0

    // A Column still spaces around a zero height child, so with no list out
    // the gap would hang below the tiles as bare padding. Animated rather
    // than switched so it opens with the list rather than ahead of it.
    spacing: open === "" ? 0 : Theme.spaceXs

    Behavior on spacing {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    function toggle(name) {
        requestOpen(open === name ? "" : name);
    }

    // A refusal is worth showing while the list that caused it is up, but not
    // held against the next time the tile is opened.
    onOpenChanged: {
        if (open === "")
            Power.error = "";
    }

    // The tile is only worth its half of the row where there is something to
    // record with, so the pair's height comes off power either way.
    readonly property real tileHeight: power.implicitHeight

    // ---- the pair ----

    Row {
        id: pair

        width: parent.width
        spacing: Theme.spaceXs

        layoutDirection: root.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

        readonly property real cell: (width - spacing) / 2

        PowerTile {
            id: power

            width: pair.cell
            host: root.host

            expanded: root.open === "power"
            joined: listCard.height > 0

            onListToggled: root.toggle("power")
            onHoverChanged: hovered => root.hoverChanged(hovered)
        }

        RecorderTile {
            width: pair.cell
            host: root.host

            onHoverChanged: hovered => root.hoverChanged(hovered)
        }
    }

    // ---- the list ----

    // A surface of its own rather than a menu on the desktop: it is the tile
    // it came from, opened up. The two top corners on that tile's side stay
    // square so the list reads as hanging from it.
    Rectangle {
        id: listCard

        width: parent.width

        // Not clipped here: the bridge below reaches up out of these bounds to
        // meet the tile. The list inside does its own clipping instead.

        implicitHeight: root.open === "" ? 0 : powerList.wantedHeight + Theme.spaceXs * 2

        radius: 9
        color: Theme.surfaceFill

        // Squared where the tile above meets it, which is always the power
        // tile: the recorder has nothing to open.
        topLeftRadius: root.anchorRight ? radius : 0
        topRightRadius: root.anchorRight ? 0 : radius

        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: listCard
                host: root.host
            }
        }

        DropShadow {
            target: listCard
            elevation: 6
            strength: 0.35
        }

        // Bridges the gap the column leaves, under the power tile alone: the
        // list belongs to that tile, so it reaches back to that one and not to
        // its neighbour. Square at both ends, being the middle of a join.
        Rectangle {
            id: bridge

            readonly property real half: (listCard.width - Theme.spaceXs) / 2

            x: root.anchorRight ? listCard.width - half : 0
            width: half

            // Exactly the gap, tracking it as it opens rather than fixed at
            // its final size: the spacing animates from nothing, so a fixed
            // height laps onto the tile for the length of the animation.
            height: root.spacing
            y: -height
            color: listCard.color
            visible: listCard.height > 0
        }

        // The bridge is its own rectangle above the card, so it needs its own
        // blur or it shows as an unfrosted strip across the join.
        Loader {
            active: root.host !== null
            sourceComponent: CardBlur {
                target: bridge
                host: root.host
            }
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        PowerList {
            id: powerList

            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            opacity: root.open === "power" ? 1 : 0
            visible: opacity > 0

            onHoverChanged: hovered => root.hoverChanged(hovered)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
    }
}
