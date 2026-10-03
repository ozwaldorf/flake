pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import ".."
import "../widgets"
import "../services"

// Settings controls and notification history in one panel. Sized to its
// content, so with nothing playing and no notifications it is just the sliders
// and the tray.
ModalPanel {
    id: root

    // an open list puts itself away on a press anywhere else in the panel
    dismissable: layout.openGroup !== null
    keep: layout.openGroup ? layout.openGroup.card : null
    onDismissed: layout.openIn(null, "")

    // The rows, or further where an open list pops out past the last of them:
    // lists lie over what follows rather than pushing it, so the panel only
    // grows for one that would otherwise run off its end.
    contentHeight: Math.max(layout.implicitHeight, ...[connectivity, audio, session].map(g => g.y + g.height + g.overhang))

    // Set while the notification stack is on its way out, so the cards run
    // their own dismissal before the model is emptied: clearing it outright
    // takes the delegates with it and they simply disappear.
    property bool clearing: false

    // opens one of the lists by name, for a keybind
    function openList(name) {
        layout.openNamed(name);
    }

    function clearNotifications() {
        if (clearing || Notifications.count === 0)
            return;
        clearing = true;
        clearTimer.restart();
    }

    Timer {
        id: clearTimer

        // The whole sequence: the last card's wait plus its own fade, and a
        // little past that so the final frame has landed before the entries go.
        interval: Theme.stagger(Notifications.count - 1) + Theme.exitDuration + 40

        onTriggered: {
            Notifications.clear();
            root.clearing = false;
        }
    }

    // Room around the rows for what falls outside them: the distance they
    // travel on the way in, and the shadow they cast.
    //
    // The clip is here for vertical scrolling, but it cuts everything else the
    // same way, so the viewport reaches past the panel and the rows are inset
    // back by the same amount.
    readonly property real slideRoom: 12

    Flickable {
        anchors.fill: parent
        anchors.margins: -root.slideRoom

        // The column is inset back by the same room, so the content stays
        // where it was and only the clip has moved outward.
        contentHeight: root.contentHeight + root.slideRoom * 2
        clip: true

        ScrollBar.vertical: ScrollBar {
            width: 5
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: layout

            // Inset back to the panel's own bounds inside a viewport grown on
            // every side to give the slide and the shadows somewhere to go.
            x: root.slideRoom
            y: root.slideRoom
            width: parent.width - root.slideRoom * 2

            // Every section is a card or a row of them, so they all sit at one
            // gap; a wider one between sections read as padding hanging under
            // whatever was above it.
            spacing: Theme.spaceXs

            // Which group holds the open list, and which entry within it. Kept
            // here rather than in each group so opening a list closes whichever
            // was already out: two at once push the rest of the panel down past
            // what it can show, and the second is rarely wanted while the first
            // is still up.
            property var openGroup: null
            property string openList: ""

            function openIn(group, name) {
                openGroup = name === "" ? null : group;
                openList = name;
            }

            function openNamed(name) {
                const group = ({
                        wifi: connectivity,
                        bluetooth: connectivity,
                        speaker: audio,
                        mic: audio,
                        power: session
                    })[name] ?? null;
                openIn(group, group ? name : "");
            }

            // Closed with the panel, so it comes back as it was left rather
            // than holding a list open from whenever it was last up.
            Connections {
                target: root

                function onShownChanged() {
                    if (root.shown)
                        return;

                    layout.openIn(null, "");

                    // a tray menu is its own window and would otherwise be
                    // left standing over the desktop with nothing behind it
                    if (utility.openMenu)
                        utility.openMenu.visible = false;
                }
            }

            // Connectivity first, matching where the system panel puts it: it
            // is the control you reach for when something is wrong, and the
            // only one whose state you read without touching it.
            ConnectivityTiles {
                id: connectivity

                host: root
                open: layout.openGroup === connectivity ? layout.openList : ""
                onRequestOpen: name => layout.openIn(connectivity, name)
            }

            // power beside the brightness, sharing one row
            SessionTiles {
                id: session

                host: root
                anchorRight: root.anchorRight
                open: layout.openGroup === session ? layout.openList : ""
                onRequestOpen: name => layout.openIn(session, name)
            }

            AudioTiles {
                id: audio

                host: root
                open: layout.openGroup === audio ? layout.openList : ""
                onRequestOpen: name => layout.openIn(audio, name)
            }

            // ---- now playing, only when a player exists ----

            MediaCard {
                id: media

                width: parent.width
                player: Media.player
                host: root
                live: root.shown
                visible: Media.player !== null
            }

            // ---- tray ----

            // One flow rather than a fixed row, so a long tray wraps onto as
            // many lines as it needs.
            Flow {
                id: utility

                width: parent.width
                visible: trayCount > 0
                spacing: Theme.spaceXs

                // Filled from the edge the rail is on, so the tray leads the
                // row from whichever side the panel opened from and trails
                // away toward the middle of the screen.
                layoutDirection: root.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

                readonly property int trayCount: SystemTray.items.values.length

                // whichever entry has its menu up, or null; one at a time
                property var openMenu: null

                // Entries are square and about as tall as the tiles above them,
                // read off the pair rather than repeated as a number so they
                // follow the tiles as those grow.
                //
                // As many as come nearest that size per line, then sized to
                // divide the line exactly: sized to the tile alone, a line a
                // couple of pixels short of one more entry wraps it and leaves
                // a gap at the end that reads as a missing tile.
                readonly property int perLine: Math.max(1, Math.round((width + spacing) / (session.tileHeight + spacing)))

                // A hair under the exact share, so rounding in the sum cannot
                // push the last entry on a line over the edge and wrap it.
                readonly property real entry: (width - (perLine - 1) * spacing) / perLine - 0.01

                // Each line is filled edge to edge however few entries it
                // holds, the entries taking it in uneven shares so the line
                // reads as a set of tiles rather than a grid with gaps. The
                // shares come from a fixed run of weights, so an entry keeps
                // its size from one opening to the next.
                readonly property var weights: [1.0, 1.6, 1.25, 1.45, 1.1, 1.35]

                function widthFor(index) {
                    const start = Math.floor(index / perLine) * perLine;
                    const count = Math.min(perLine, trayCount - start);
                    let total = 0;
                    for (let i = start; i < start + count; i++)
                        total += weights[i % weights.length];
                    const room = width - (count - 1) * spacing - 0.01 * count;
                    return room * weights[index % weights.length] / total;
                }

                Repeater {
                    model: SystemTray.items

                    Card {
                        id: trayEntry

                        required property var modelData
                        required property int index

                        // As tall as the tile beside it so the row reads as
                        // one band, and as wide as its share of the line.
                        implicitWidth: utility.widthFor(index)
                        implicitHeight: utility.entry
                        host: root
                        cursorShape: Qt.PointingHandCursor

                        // Decoded at device resolution rather than at the 16
                        // logical pixels it draws into. Without a sourceSize
                        // Qt renders the icon at whatever size the source
                        // happens to be and rescales, which on a fractional
                        // scale display is a resample either way; asking for
                        // the real pixel count gets a crisp icon instead.
                        //
                        // Quickshell's tray icons carry a size hint in the
                        // URL, so the request has to reach the provider rather
                        // than only the painter.
                        Image {
                            // Sized off the entry so it keeps its inset as
                            // the entry follows the tile's height, rather
                            // than a fixed size floating in a bigger box.
                            readonly property real side: Math.round(trayEntry.height * 0.44)
                            readonly property int px: Math.ceil(side * Screen.devicePixelRatio)

                            anchors.centerIn: parent
                            width: side
                            height: side
                            sourceSize.width: px
                            sourceSize.height: px
                            source: trayEntry.modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        // Rendered from the DBusMenu tree rather than handed to
                        // QsMenuAnchor, which opens Qt's native widget menu and
                        // ignores the shell's styling.
                        TrayMenu {
                            id: trayMenu

                            screenData: root.modelData
                            handle: trayEntry.modelData.menu
                            anchorItem: trayEntry
                            anchorRight: root.anchorRight
                            // this panel is right anchored on the right hand
                            // monitor, so its window origin is not screen zero
                            anchorWindowX: root.anchorRight ? root.screen.width - root.width : 0

                            // The menu is its own window, so the panel cannot
                            // see the pointer once it moves onto it. Hold the
                            // panel open for as long as the menu is, and
                            // release that hold if the tray item goes away
                            // while its menu is still up.
                            //
                            // Registering as the open one here rather than
                            // binding visible to the tray's key, since the menu
                            // writes its own visible when it dismisses itself
                            // and a binding would be broken by that write.
                            onVisibleChanged: {
                                root.hold(visible);

                                if (visible)
                                    utility.openMenu = trayMenu;
                                else if (utility.openMenu === trayMenu)
                                    utility.openMenu = null;
                            }

                            Component.onDestruction: {
                                if (!visible)
                                    return;

                                // torn down while up: nothing else will emit
                                // the change that would release these
                                root.hold(false);
                                if (utility.openMenu === trayMenu)
                                    utility.openMenu = null;
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onSingleTapped: (eventPoint, button) => {
                                // items flagged onlyMenu have no activate action
                                if (button === Qt.RightButton || trayEntry.modelData.onlyMenu) {
                                    // close whatever else was up first: the
                                    // menus are separate windows and nothing
                                    // dismisses one because another opened
                                    if (utility.openMenu && utility.openMenu !== trayMenu)
                                        utility.openMenu.visible = false;

                                    trayMenu.visible = !trayMenu.visible;
                                } else {
                                    trayEntry.modelData.activate();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Notification cards live below the panel as their own surfaces rather than
    // inside it, so each keeps its own fill, rounding and blur.
    detached: Repeater {
        model: Notifications.history

        NotificationCard {
            id: card

            required property var model
            required property int index

            width: parent.width
            anchorRight: root.anchorRight
            entry: model
            recessed: true

            // Faded in on arrival, and out while the stack is being cleared, so
            // the cards leave rather than the model emptying out from under
            // them. Not on the panel opening or closing: the drawer uncovers
            // and covers them where they stand.
            opacity: 0

            RevealSlide {
                target: card
                index: 0
                shown: !root.clearing
                fromRight: root.anchorRight

                // Sequenced only when the stack is being cleared, and from the
                // bottom up: the panel's own dismissal takes them together, but
                // clearing happens with the panel still open and reads better
                // as the stack emptying than as everything going at once.
                staggerExit: root.clearing
                exitIndex: Notifications.count - 1 - card.index
            }

            // Blur switched at the halfway point of the card's fade like every
            // other surface.
            //
            // parent is guarded throughout: on dismissal the delegate is
            // reparented to null before its bindings are torn down, so an
            // unguarded card.parent.x throws for a frame.
            Region {
                id: cardRegion

                readonly property bool active: card.opacity > 0.5

                // Window coordinates, summed from properties rather than via
                // mapToItem: that is a one shot call with no dependency
                // tracking, so the binding would never re-evaluate when the
                // card moves or the stack scrolls.
                readonly property real originX: root.detachedLeft
                readonly property real originY: root.detachedTop + card.y - root.detachedScroll

                // clipped to the viewport so a scrolled out card does not blur
                // a strip outside it
                readonly property real top: Math.max(originY, root.detachedTop)
                readonly property real bottom: Math.min(originY + card.height, root.detachedBottom)
                readonly property bool inView: bottom > top

                x: originX
                y: top
                width: active && inView ? card.width : 0
                height: active && inView ? bottom - top : 0
                radius: card.radius
            }

            Component.onCompleted: root.detachedRegions.push(cardRegion)
            Component.onDestruction: {
                const i = root.detachedRegions.indexOf(cardRegion);
                if (i >= 0)
                    root.detachedRegions.splice(i, 1);
            }

            TapHandler {
                onTapped: Notifications.remove(card.model.id)
            }
        }
    }

    // Clearing every notification, pinned to the foot of the drawer rather
    // than among the cards it acts on: a control in the stack reads as one
    // more thing to read. A small button while there is something to clear,
    // and a line saying there is nothing otherwise, in the same spot.
    footer: Item {
        id: foot

        readonly property bool has: Notifications.count > 0 && !root.clearing

        width: parent.width
        // the button's own height, or with nothing to clear, all the room
        // under the panel so the line saying so sits in the middle of it
        height: has ? clearAll.height : Math.max(clearAll.height, root.freeBelow - Theme.spaceSm)

        Card {
            id: clearAll

            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: clearLabel.implicitWidth + Theme.spaceSm * 2
            implicitHeight: clearLabel.implicitHeight + Theme.spaceXs * 2
            radius: height / 2
            cursorShape: Qt.PointingHandCursor
            opacity: foot.has ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Fade {}
            }

            Label {
                id: clearLabel

                anchors.centerIn: parent
                text: "Clear all"
                color: clearAll.hovered ? Theme.red : Theme.overlay1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }
            }

            TapHandler {
                enabled: foot.has
                onTapped: root.clearNotifications()
            }
        }

        Label {
            anchors.centerIn: parent
            text: "No new notifications"
            color: Theme.surface2
            opacity: foot.has ? 0 : 1
            visible: opacity > 0

            Behavior on opacity {
                Fade {}
            }
        }
    }
}
