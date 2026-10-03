pragma ComponentBehavior: Bound

import QtQuick
import ".."

// Tiles side by side over one shared list area. Only one list is ever open:
// the tiles are peers, and two lists out at once would bury the panel.
//
// Opening a tile does not grow it in place. A larger card fades in over the
// whole row, lifted out of the drawer's wells: the tile's own glyph, name and
// state across its head, laid out for the room, and the list under that. It
// lies over whatever follows rather than pushing it down.
Item {
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

    // cap on the list, past which it scrolls
    property real maxListHeight: 200

    // the tiles, laid out across the row
    default property alias tiles: row.data
    property alias tileRow: row

    // The lists, one per disclosing tile, each named by its objectName and
    // carrying a wantedHeight.
    property list<Item> lists

    // the list last opened and the tile it belongs to, held through the fade
    // out so the card keeps its contents while it goes
    readonly property Item heldList: {
        for (let i = 0; i < lists.length; i++) {
            if (lists[i].objectName === joinedTo)
                return lists[i];
        }
        return null;
    }
    readonly property Item heldTile: {
        for (let i = 0; i < row.children.length; i++) {
            if (row.children[i].listName === joinedTo)
                return row.children[i];
        }
        return null;
    }

    // the expanded card, for a panel that has to tell a click on it from one
    // beside it
    readonly property Item card: expanded

    // set while the expanded card shows at all, including its fade out
    readonly property bool joined: expanded.visible

    width: parent ? parent.width : 0

    // Only the tiles take room; the card lies over whatever follows, so the
    // group is raised above its later siblings while one is out.
    implicitHeight: row.height
    z: joined ? 1 : 0

    // how far the card reaches past the group's own height, for a layout that
    // has to keep it on screen
    readonly property real overhang: joined ? expanded.height - row.height : 0

    Row {
        id: row

        width: parent.width
        spacing: Theme.spaceXs
    }

    Card {
        id: expanded

        readonly property Item tile: root.heldTile

        // an audio card carries its level in its head
        readonly property bool level: tile && tile.value !== undefined

        // Two thirds of the row, or the tile's own width where that is more,
        // set on the tile's corner: from its left edge where there is room
        // to the right, otherwise back from its right edge.
        readonly property real tileX: tile ? tile.x : 0
        readonly property real tileWidth: tile ? tile.width : 0

        width: Math.max(tileWidth, (parent.width - row.spacing) * 2 / 3)
        x: tileX + width <= parent.width + 0.5 ? tileX : tileX + tileWidth - width
        height: head.height + 1 + (root.heldList ? Math.min(root.heldList.wantedHeight, root.maxListHeight) + Theme.spaceXs * 2 : 0)
        host: root.host
        lifts: false
        recessed: false

        // Solid rather than the raised cards' frosted fill: it lies over the
        // tiles, and they would show through it.
        color: Theme.base

        opacity: root.open !== "" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            // Only while the drawer is out: closed, its window draws no
            // frames, so a fade begun as it shut would sit half done until
            // it next opened.
            enabled: root.host?.shown ?? true

            Fade {}
        }

        // Covers the tiles under it, so none of them takes a click, a hover
        // or a scroll meant for the card above: a wheel over a short list
        // would otherwise run on into the brightness beneath.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: wheel => wheel.accepted = true
        }

        Item {
            id: head

            width: parent.width
            // A toggle tile's own height, puck and padding, so the card opens
            // with the same top the tile had: the glyph where its puck was,
            // the name and state where its text was.
            height: Theme.spaceSm * 2 + 34

            // The tile's own glyph, drawn live from it so it carries the same
            // state and colours, and still the switch: a tap flips the radio
            // or the mute as it would on the tile.
            ShaderEffectSource {
                id: lead

                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                width: sourceItem ? sourceItem.width : 0
                height: sourceItem ? sourceItem.height : 0
                sourceItem: expanded.tile ? expanded.tile.lead : null
                live: true

                // A MouseArea rather than a tap handler, here and on the
                // controls below: it takes the press outright, where a
                // handler's claim on it gives way to the card's own catch-all
                // underneath.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (expanded.level)
                            expanded.tile.muteToggled();
                        else if (expanded.tile.switchable)
                            expanded.tile.toggled();
                    }
                }
            }

            Column {
                anchors.left: lead.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: controls.left
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Label {
                    width: parent.width
                    text: expanded.tile ? expanded.tile.label : ""
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Label {
                    width: parent.width
                    text: expanded.tile ? expanded.tile.status : ""
                    visible: text !== ""
                    color: expanded.tile && expanded.tile.warn ? Theme.peach : Theme.overlay1
                    elide: Text.ElideRight
                }
            }

            Row {
                id: controls

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceSm
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm

                // the level as a figure, for an audio card
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: expanded.level
                    text: expanded.level ? (expanded.tile.muted ? "muted" : Math.round(expanded.tile.clamped * 100) + "%") : ""
                    figures: true
                    color: Theme.overlay1
                }

                // folds the card back into its tile
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32

                    Chevron {
                        anchors.centerIn: parent
                        rotation: -90
                        fill: closeHover.containsMouse ? Theme.text : Theme.overlay0
                    }

                    MouseArea {
                        id: closeHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(root.joinedTo)
                    }
                }
            }
        }

        Rectangle {
            id: rule

            anchors.top: head.bottom
            x: Theme.spaceSm
            width: parent.width - Theme.spaceSm * 2
            height: 1
            color: Qt.alpha(Theme.surface1, 0.6)
        }

        Item {
            anchors.top: rule.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Repeater {
                model: root.lists

                Item {
                    id: slot

                    required property Item modelData

                    anchors.fill: parent
                    anchors.margins: Theme.spaceXs
                    visible: root.joinedTo === modelData.objectName

                    Component.onCompleted: {
                        modelData.parent = slot;
                        modelData.anchors.fill = slot;
                    }
                }
            }
        }
    }
}
