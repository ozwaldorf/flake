pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
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

    title: "Control centre"

    headerAction: Notifications.count > 0 ? "Clear all" : ""
    onHeaderActionTriggered: Notifications.clear()

    contentHeight: layout.implicitHeight

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.padPanel
        contentHeight: layout.implicitHeight
        clip: true

        ScrollBar.vertical: ScrollBar {
            width: 5
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: layout

            readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

            width: parent.width

            // Every section is a card or a row of them, so they all sit at one
            // gap; a wider one between sections read as padding hanging under
            // whatever was above it.
            spacing: Theme.spaceXs

            // Connectivity first, matching where the system panel puts it: it
            // is the control you reach for when something is wrong, and the
            // only one whose state you read without touching it.
            ConnectivityTiles {
                width: parent.width
                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            BrightnessCard {
                width: parent.width
                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            VolumeSlider {
                width: parent.width
                device: "speaker"
                label: "Volume"
                value: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                muted: Pipewire.defaultAudioSink?.audio?.muted ?? false
                onMoved: v => {
                    if (Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.volume = v;
                }
                onMuteToggled: {
                    if (Pipewire.defaultAudioSink?.audio)
                        Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                }
                onHoverChanged: hovered => root.setChildHovered(hovered)
            }

            VolumeSlider {
                width: parent.width
                device: "mic"
                label: "Microphone"
                value: Pipewire.defaultAudioSource?.audio?.volume ?? 0
                muted: Pipewire.defaultAudioSource?.audio?.muted ?? false
                onMoved: v => {
                    if (Pipewire.defaultAudioSource?.audio)
                        Pipewire.defaultAudioSource.audio.volume = v;
                }
                onMuteToggled: {
                    if (Pipewire.defaultAudioSource?.audio)
                        Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted;
                }
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

            Row {
                id: utility

                width: parent.width
                spacing: Theme.spaceXs

                readonly property int trayCount: SystemTray.items.values.length

                // Entries are square and as tall as the row, so what the tray
                // needs is known before laying anything out. Fixed rather than
                // derived from the tile, which now derives from this.
                readonly property real entry: 54

                readonly property real trayWidth: trayCount > 0 ? trayCount * entry + (trayCount - 1) * spacing : 0

                // The recorder takes whatever the tray does not, so an uneven
                // remainder ends up in the tile rather than as a gap at the end
                // of the row. Floored at half so a crowded tray cannot squeeze
                // the status line out.
                readonly property real cell: Math.max((width - spacing) / 2, trayCount > 0 ? width - trayWidth - spacing : width)

                RecorderTile {
                    id: recorder

                    width: utility.cell
                    onHoverChanged: hovered => root.setChildHovered(hovered)
                }

                Flow {
                    width: utility.trayWidth
                    spacing: Theme.spaceXs
                    visible: utility.trayCount > 0

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

                            // same surface as the tiles and the level cards: half
                            // alpha at rest, lifting to solid under the pointer
                            color: trayHover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0.5)

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
                                onVisibleChanged: root.setChildHovered(visible)

                                Component.onDestruction: {
                                    if (visible)
                                        root.setChildHovered(false);
                                }
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onSingleTapped: (eventPoint, button) => {
                                    // items flagged onlyMenu have no activate action
                                    if (button === Qt.RightButton || trayEntry.modelData.onlyMenu)
                                        trayMenu.visible = !trayMenu.visible;
                                    else
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

            // Each card starts while the panel is still fading and one stagger
            // step behind the card above it, so the fades overlap and the whole
            // set lands quickly. Closing is not staggered: they all drop with
            // the panel so dismissal stays crisp.
            opacity: 0

            Connections {
                target: root

                function onShownChanged() {
                    if (root.shown)
                        revealIn.restart();
                    else
                        fadeOut.restart();
                }
            }

            SequentialAnimation {
                id: revealIn

                PauseAnimation {
                    duration: Theme.staggerLead + card.index * Theme.staggerStep
                }
                NumberAnimation {
                    target: card
                    property: "opacity"
                    to: 1
                    duration: Theme.fadeDuration
                    easing.type: Easing.OutQuad
                }
            }

            NumberAnimation {
                id: fadeOut

                target: card
                property: "opacity"
                to: 0
                duration: Theme.fadeDuration
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
