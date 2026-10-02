pragma ComponentBehavior: Bound

import QtQuick
import ".."

// Tiles side by side over one shared list area. Only one list is ever open:
// the tiles are peers, and stacking two open lists would push everything below
// them off the panel.
//
// The list is a surface of its own, joined to the tile it came from: the top
// corners on that tile's side stay square and a bridge fills the gap above
// them, so it reads as that tile opened up rather than as a separate card that
// happens to be underneath.
Column {
    id: root

    // passed down to the cards, which each frost their own rectangle
    property var host: null

    // Which list is showing, by its objectName, or empty. Held by whatever
    // lays these out rather than here, so opening a list anywhere in the panel
    // closes whichever one was already out.
    property string open: ""

    signal requestOpen(string name)

    function toggle(name) {
        requestOpen(open === name ? "" : name);
    }

    // The list that was last opened, held through a collapse rather than
    // following open, which clears the moment the tile is clicked: the card is
    // still on its way down, and switching then would swing the join across to
    // the other tile for the length of the animation.
    property string joinedTo: ""

    // a Connections rather than a handler, which a layout handling the same
    // signal itself would otherwise be taken to override
    Connections {
        target: root

        function onOpenChanged() {
            if (root.open !== "")
                root.joinedTo = root.open;
        }
    }

    Component.onCompleted: {
        if (open !== "")
            joinedTo = open;
    }

    // Where the open tile sits across the row, which is what the bridge spans
    // and which corners square off. Set by the layout from joinedTo.
    property real joinLeft: 0
    property real joinRight: width

    // cap on the list, past which it scrolls
    property real maxListHeight: 200

    // the tiles, laid out across the row
    default property alias tiles: row.data
    property alias tileRow: row

    // The lists, one per disclosing tile, each named by its objectName and
    // carrying a wantedHeight. Cross faded rather than both taking space.
    property list<Item> lists

    readonly property Item openList: {
        for (let i = 0; i < lists.length; i++) {
            if (lists[i].objectName === open)
                return lists[i];
        }
        return null;
    }

    // set while the list card has any height at all, including its collapse
    readonly property bool joined: listCard.height > 0

    width: parent ? parent.width : 0

    // A Column still spaces around a zero height child, so with no list out
    // the gap would hang below the tiles as bare padding. Animated rather than
    // switched so it opens with the list rather than ahead of it.
    spacing: open === "" ? 0 : Theme.spaceXs

    Behavior on spacing {
        Morph {}
    }

    Row {
        id: row

        width: parent.width
        spacing: Theme.spaceXs
    }

    Card {
        id: listCard

        width: parent.width
        host: root.host
        lifts: false

        // Not clipped here: the bridge below reaches up out of these bounds to
        // meet the tile. The lists inside do their own clipping instead.
        implicitHeight: root.openList ? Math.min(root.openList.wantedHeight, root.maxListHeight) + Theme.spaceXs * 2 : 0

        Behavior on implicitHeight {
            Morph {}
        }

        // squared where the tile above meets it, eased so the two corners
        // trade shape as the join moves rather than jumping
        topLeftRadius: root.joinLeft > 0 ? radius : 0
        topRightRadius: root.joinRight < width ? radius : 0

        Behavior on topLeftRadius {
            Morph {}
        }

        Behavior on topRightRadius {
            Morph {}
        }

        // Bridges the gap the column leaves, under the open tile alone. Square
        // at both ends, being the middle of a join.
        Rectangle {
            id: bridge

            // Both edges are animated in their own right rather than a width
            // and a position derived from it: with x computed from an
            // animating width, travelling outward drags the near edge inward
            // first as the width shrinks, and only then slides out.
            //
            // not readonly: a Behavior writes to what it animates
            property real leftEdge: root.joinLeft
            property real rightEdge: root.joinRight

            Behavior on leftEdge {
                Morph {}
            }

            Behavior on rightEdge {
                Morph {}
            }

            x: leftEdge
            width: Math.max(0, rightEdge - leftEdge)

            // Exactly the gap, tracking it as it opens rather than fixed at its
            // final size: the spacing animates from nothing, so a fixed height
            // laps onto the tile for the length of the animation, and two
            // translucent surfaces overlapping show as a line.
            height: root.spacing
            y: -height

            color: listCard.color
            visible: root.joined
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

        Repeater {
            model: root.lists

            Item {
                id: slot

                required property Item modelData

                anchors.fill: parent
                anchors.margins: Theme.spaceXs
                opacity: root.open === modelData.objectName ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    Fade {}
                }

                Component.onCompleted: {
                    modelData.parent = slot;
                    modelData.anchors.fill = slot;
                }
            }
        }
    }
}
