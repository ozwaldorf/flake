pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import ".."
import "../widgets"
import "../services"

// Settings controls and notification history in one panel. Sized to its
// content, so with nothing playing and no notifications it is just the sliders
// and the tray.
ModalPanel {
    id: root

    contentHeight: layout.implicitHeight

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
        contentHeight: layout.implicitHeight + root.slideRoom * 2
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

            readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

            // how many rows the controls take, so the notification cards below
            // carry on the same sequence rather than starting a second one
            readonly property int rows: 4

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

                width: parent.width

                open: layout.openGroup === connectivity ? layout.openList : ""
                onRequestOpen: name => layout.openIn(connectivity, name)

                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            BrightnessCard {
                id: brightness

                host: root
                width: parent.width
                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            AudioTiles {
                id: audio

                host: root

                width: parent.width

                open: layout.openGroup === audio ? layout.openList : ""
                onRequestOpen: name => layout.openIn(audio, name)

                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            // ---- now playing, only when a player exists ----

            Row {
                width: parent.width
                spacing: Theme.space
                visible: layout.player !== null

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: 6
                    color: Theme.surface0

                    Image {
                        anchors.fill: parent
                        source: layout.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    width: parent.width - 52 - Theme.space
                    spacing: 3

                    Text {
                        width: parent.width
                        text: layout.player?.trackTitle ?? ""
                        font.family: Theme.font
                        font.pixelSize: 11
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: layout.player?.trackArtist ?? ""
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: Theme.overlay0
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 8
                        topPadding: 3

                        MediaButton {
                            symbol: "prev"
                            enabled: layout.player?.canGoPrevious ?? false
                            onTriggered: layout.player.previous()
                            onHoveredChanged: root.setChildHovered(hovered)
                        }

                        MediaButton {
                            symbol: layout.player?.isPlaying ? "pause" : "play"
                            enabled: layout.player?.canTogglePlaying ?? false
                            onTriggered: layout.player.togglePlaying()
                            onHoveredChanged: root.setChildHovered(hovered)
                        }

                        MediaButton {
                            symbol: "next"
                            enabled: layout.player?.canGoNext ?? false
                            onTriggered: layout.player.next()
                            onHoveredChanged: root.setChildHovered(hovered)
                        }
                    }
                }
            }

            // ---- recorder and tray, sharing one row ----

            // One flow rather than a tile beside a tray: with the recorder as
            // its first item, wrapping packs every line as full as it goes
            // instead of the tray having to fit whatever the tile left over.
            Flow {
                id: utility

                width: parent.width
                spacing: Theme.spaceXs

                // Filled from the edge the rail is on, so the recorder leads
                // the row from whichever side the panel opened from and the
                // tray trails away toward the middle of the screen.
                layoutDirection: root.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

                readonly property int trayCount: SystemTray.items.values.length

                // whichever entry has its menu up, or null; one at a time
                property var openMenu: null

                // Entries are square and as tall as the tile beside them, so
                // what they need is known before laying anything out.
                //
                // Read off the recorder rather than repeated as a number: the
                // tiles size themselves from the spacing scale, and a literal
                // here stays put while they grow. Its height does not depend
                // on its width, so taking it while giving the tile a width
                // derived from this is not circular.
                readonly property real entry: recorder.implicitHeight

                // Entries sharing the recorder's line: whatever fits once the
                // tile has taken its half, and never more than there are.
                readonly property int fits: Math.min(trayCount, Math.max(1, Math.floor(((width - spacing) / 2 + spacing) / (entry + spacing))))

                // Taking every entry that fits can leave one alone on the line
                // below, which reads as a stray rather than a row. Giving one
                // back pairs it up, and only helps when exactly one was
                // stranded: with more than that the line below is a row
                // already, and with none there is nothing to fix.
                readonly property int beside: trayCount - fits === 1 && fits > 1 ? fits - 1 : fits

                // The tile takes the line's leftover, so an uneven remainder
                // ends up in it rather than as a gap at the end of the row.
                // With no tray at all it takes the whole width.
                readonly property real cell: trayCount > 0 ? width - beside * (entry + spacing) : width

                // How many entries land on the line under the recorder, and so
                // what is left of it for the clear tile to finish. A full line
                // leaves nothing, in which case the tile takes a line of its
                // own and fills it.
                readonly property int wrapped: trayCount - beside
                readonly property int onLastLine: wrapped === 0 ? 0 : wrapped % Math.max(1, Math.floor((width + spacing) / (entry + spacing)))

                readonly property real clearCell: onLastLine === 0 ? width : width - onLastLine * (entry + spacing)

                RecorderTile {
                    id: recorder

                    host: root

                    width: utility.cell
                    onHoverChanged: hovered => root.setChildHovered(hovered)
                }

                Repeater {
                    model: SystemTray.items

                    Rectangle {
                        id: trayEntry

                        required property var modelData

                        // Square, and as tall as the tile beside it so the
                        // row reads as one band rather than icons floating
                        // against a taller card.
                        implicitWidth: utility.entry
                        implicitHeight: utility.entry
                        radius: 9

                        // same surface as the tiles and the level cards, each
                        // frosting its own rectangle
                        color: trayHover.hovered ? Qt.tint(Theme.surfaceFill, Qt.alpha(Theme.text, 0.06)) : Theme.surfaceFill

                        CardBlur {
                            target: trayEntry
                            host: root
                        }

                        DropShadow {
                            target: trayEntry
                            elevation: trayHover.hovered ? 9 : 6
                            strength: trayHover.hovered ? 0.45 : 0.35
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }

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
                            id: trayIcon

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

                        HoverHandler {
                            id: trayHover
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: root.setChildHovered(hovered)
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

                            // The menu is its own window, so the panel's hover
                            // surface cannot see the pointer once it moves onto
                            // it. Hold the panel open for as long as the menu
                            // is, and release that hold if the tray item goes
                            // away while its menu is still up: the panel would
                            // otherwise stay open with nothing holding it.
                            //
                            // Registering as the open one here rather than
                            // binding visible to the tray's key, since the menu
                            // writes its own visible when it dismisses itself
                            // and a binding would be broken by that write.
                            onVisibleChanged: {
                                root.setChildHovered(visible);

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
                                root.setChildHovered(false);
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

                // Clearing every notification, with the settings rather than on
                // the stack it acts on: the stack is a list of things to read, and
                // a control among them reads as one of them.
                Rectangle {
                    id: clearAll

                    // Present whether or not there is anything to clear: an
                    // empty stack is worth stating, and a tile that came and
                    // went would reflow the row under the pointer.
                    readonly property bool has: Notifications.count > 0

                    // finishes whatever line the tray left off on, or takes one
                    // of its own when the tray filled the last one exactly
                    width: utility.clearCell
                    implicitHeight: utility.entry
                    radius: 9

                    color: clearAll.has && clearHover.hovered ? Qt.tint(Theme.surfaceFill, Qt.alpha(Theme.text, 0.06)) : Theme.surfaceFill

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    CardBlur {
                        target: clearAll
                        host: root
                    }

                    DropShadow {
                        target: clearAll
                        elevation: clearAll.has && clearHover.hovered ? 9 : 6
                        strength: clearAll.has && clearHover.hovered ? 0.45 : 0.35
                    }

                    Text {
                        anchors.centerIn: parent

                        text: clearAll.has ? "Clear " + Notifications.count + " notification" + (Notifications.count === 1 ? "" : "s") : "No new notifications"
                        font.family: Theme.font
                        font.pixelSize: 10

                        // dimmer with nothing to say, and only red when there
                        // is something a click would actually discard
                        color: !clearAll.has ? Theme.surface2 : clearHover.hovered ? Theme.red : Theme.overlay1

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }
                        }
                    }

                    HoverHandler {
                        id: clearHover
                        cursorShape: clearAll.has ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onHoveredChanged: root.setChildHovered(hovered)
                    }

                    TapHandler {
                        enabled: clearAll.has
                        onTapped: Notifications.clear()
                    }
                }
            }
        }
    }

    // Each row arrives a step behind the one above it, sliding in from the
    // edge the panel opened from. Declared out here rather than inside the
    // rows: a Column lays out every child it has, and these would each take a
    // slot of their own.
    RevealSlide {
        target: connectivity
        index: 0
        shown: root.shown
        fromRight: root.anchorRight
    }

    RevealSlide {
        target: brightness
        index: 1
        shown: root.shown
        fromRight: root.anchorRight
    }

    RevealSlide {
        target: audio
        index: 2
        shown: root.shown
        fromRight: root.anchorRight
    }

    RevealSlide {
        target: utility
        index: 3
        shown: root.shown
        fromRight: root.anchorRight
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

            // Each card arrives a step behind the one above it, continuing the
            // sequence the control rows started rather than beginning a second
            // one: the stack reads as one set coming in.
            opacity: 0

            RevealSlide {
                target: card
                index: layout.rows + card.index
                shown: root.shown
                fromRight: root.anchorRight
            }

            onChildHoverChanged: hovered => root.setChildHovered(hovered)

            // Blur switched at the halfway point of the fade like every other
            // surface. The fade lives on the containing column, not the card.
            //
            // parent is guarded throughout: on dismissal the delegate is
            // reparented to null before its bindings are torn down, so an
            // unguarded card.parent.x throws for a frame.
            Region {
                id: cardRegion

                // the fade now lives on the card itself, not the column
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

            Component.onCompleted: {
                root.detachedRegions.push(cardRegion);
                if (root.shown)
                    revealIn.restart();
            }
            Component.onDestruction: {
                // NotificationCard releases its own outstanding hover raises,
                // so nothing to undo here beyond the blur region
                const i = root.detachedRegions.indexOf(cardRegion);
                if (i >= 0)
                    root.detachedRegions.splice(i, 1);
            }

            TapHandler {
                onTapped: Notifications.remove(card.model.id)
            }
        }
    }
}
