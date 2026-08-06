pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
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

    // Set while the notification stack is on its way out, so the cards run
    // their own dismissal before the model is emptied: clearing it outright
    // takes the delegates with it and they simply disappear.
    property bool clearing: false

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
        interval: Math.max(0, Notifications.count - 1) * Theme.staggerStep + Theme.fadeDuration + 40

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
            // carry on the same sequence rather than starting a second one.
            // The media card only counts when there is a player, so with
            // nothing playing the sequence closes up rather than leaving its
            // step as a pause in the middle.
            readonly property int rows: player !== null ? 5 : 4

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

            // A card like the levels above it, each frosting its own
            // rectangle. Its height matches the slider tiles so the stack
            // reads as one column of surfaces rather than a bare row among
            // them.
            Rectangle {
                id: media

                width: parent.width
                implicitHeight: 86
                radius: 9
                visible: layout.player !== null

                color: mediaHover.hovered ? Qt.tint(Theme.surfaceFill, Qt.alpha(Theme.text, 0.06)) : Theme.surfaceFill

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                // The sleeve's colour washing in from the record's side and
                // gone by the middle of the card.
                //
                // Laid over the card's own fill rather than replacing it: a
                // gradient on the rectangle would take the place of the colour
                // the hover tint animates, and the fill is semi transparent
                // over the blur, so an opaque wash here would show as a patch
                // through the frosting. This fades to fully transparent and
                // lets the card show through instead.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius

                    // Follows the side the record is on, so the colour comes
                    // from the art rather than across the card at it.
                    //
                    // Held at full strength until just past the record before
                    // it starts to go: the art only takes the first quarter of
                    // the card, so a fade beginning at the edge is already
                    // thinning out behind the art itself. It carries the whole
                    // width from there, so the colour runs out at the far edge
                    // rather than stopping short and leaving a seam.
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: Qt.alpha(art.accent, 0.28)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fadeDuration
                                }
                            }
                        }

                        GradientStop {
                            // just past the record's far edge
                            position: 0.22
                            color: Qt.alpha(art.accent, 0.28)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fadeDuration
                                }
                            }
                        }

                        GradientStop {
                            position: 1
                            color: Qt.alpha(art.accent, 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fadeDuration
                                }
                            }
                        }
                    }
                }

                CardBlur {
                    target: media
                    host: root
                }

                DropShadow {
                    target: media
                    elevation: mediaHover.hovered ? 9 : 6
                    strength: mediaHover.hovered ? 0.45 : 0.35
                }

                // Reported upward like the other cards: the panel dismisses on
                // losing the pointer, and the buttons alone do not cover it.
                HoverHandler {
                    id: mediaHover
                    onHoveredChanged: root.setChildHovered(hovered)
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceSm

                    // The art as a record: round, turning while the track
                    // plays and holding its angle when it stops.
                    //
                    // Sized on the card's inner height, so it grows with the
                    // card rather than sitting in it at a fixed size.
                    Item {
                        id: art

                        width: parent.height
                        height: parent.height

                        // How thick the rim is, and so how far the record is
                        // inset from the tile to leave room for it. Qt draws a
                        // border inward from the bounds, so a rim on the disc
                        // itself would be laid over the art rather than around
                        // it; the ring is its own circle and the disc shrinks
                        // to sit inside it.
                        readonly property real rim: 3

                        // The record's own colour, taken from the art so the
                        // rim carries the sleeve rather than one grey for
                        // everything.
                        //
                        // Quantised over the whole image: a handful of colours
                        // by median cut, and the one with the most life in it
                        // wins. Falls back to the plain rim while there is no
                        // art, or none that yields a usable colour.
                        ColorQuantizer {
                            id: sleeve

                            // Only asked for once there is a cover: the site
                            // icon is a logo rather than art, and colouring
                            // the record by it says nothing about the track.
                            source: thumb.showingCover ? thumb.source : ""

                            // Four levels, so sixteen buckets: enough to
                            // separate a sleeve's few real colours without
                            // splitting them into near duplicates.
                            depth: 4

                            // Sampled small; the dominant colour of a cover
                            // does not need every pixel to find.
                            rescaleSize: 64
                        }

                        // The most saturated of the quantised colours, kept
                        // clear of the ends: a sleeve's average tends to mud,
                        // and near black or near white carries no hue to
                        // speak of. Falls back to the flat rim when nothing
                        // qualifies.
                        readonly property color accent: {
                            const fallback = Qt.alpha(Theme.crust, 0.55);
                            const colors = sleeve.colors;
                            if (!colors || colors.length === 0)
                                return fallback;

                            let best = null;
                            let bestScore = 0;

                            for (const c of colors) {
                                // Weighted toward saturation but held back
                                // from the extremes of lightness, where a
                                // strong reading of hue is not a strong
                                // colour.
                                const room = 1 - Math.abs(c.hsvValue - 0.55) * 1.6;
                                const score = c.hsvSaturation * Math.max(0, room);

                                if (score > bestScore) {
                                    bestScore = score;
                                    best = c;
                                }
                            }

                            // Nothing with any colour in it: a greyscale
                            // sleeve reads better with the plain rim than with
                            // a tinted grey.
                            return best && bestScore > 0.05 ? best : fallback;
                        }

                        // Driven as an angle that only ever increases, rather
                        // than a zero to 360 loop: a loop restarts from its
                        // "from" every time it runs, so pausing and playing
                        // would snap the record back to the top. Each leg
                        // starts from wherever the last one was stopped.
                        property real spin: 0

                        readonly property bool turning: layout.player?.isPlaying ?? false

                        // one revolution, so the leg length sets the speed
                        readonly property int revolution: 8000

                        // The from and to are captured when the animation
                        // starts and replayed for every loop, so each
                        // revolution repeats the same leg. That is seamless
                        // only because the leg is exactly 360 degrees: the
                        // jump back at the loop boundary is a whole turn, and
                        // a whole turn is no turn at all. Any other leg length
                        // here would visibly snap.
                        NumberAnimation {
                            id: spinner

                            target: art
                            property: "spin"
                            from: art.spin
                            to: art.spin + 360
                            duration: art.revolution
                            loops: Animation.Infinite
                        }

                        // Restarted on each change so the new leg picks up the
                        // angle the old one stopped at. Stopping alone leaves
                        // spin where it stands, which is the hold.
                        onTurningChanged: {
                            if (turning)
                                spinner.restart();
                            else
                                spinner.stop();
                        }

                        Component.onCompleted: {
                            if (turning)
                                spinner.restart();
                        }

                        // Masked rather than clipped. Qt's clip is a
                        // rectangular scissor and Image has no radius of its
                        // own, so neither rounds a cover: it would sit as a
                        // square tile behind a round edge. The mask is the
                        // only thing that actually cuts the art to the circle.
                        Rectangle {
                            id: discMask

                            anchors.fill: parent
                            anchors.margins: art.rim
                            radius: width / 2
                            color: "white"
                            visible: false
                            layer.enabled: true
                        }

                        Rectangle {
                            id: disc

                            // Inset by the rim, which is drawn around this
                            // rather than over it. The mask is inset to match:
                            // it is a texture for exactly these bounds, so the
                            // two have to be the same size and place.
                            anchors.fill: parent
                            anchors.margins: art.rim
                            radius: width / 2
                            color: Theme.surface0
                            rotation: art.spin

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: discMask
                            }

                            // The art, in order of preference: the player's own
                            // cover, else the icon of the site it named, else
                            // nothing and the glyph below shows through.
                            //
                            // Resolved to a single source rather than stacked as a
                            // layer each: one image exists at a time, so there is
                            // no second decode sitting behind the first and no
                            // earlier tier showing through a gap in a later one.
                            //
                            // The choice is made on what the player published, not
                            // on what loaded: art that fails falls through to the
                            // glyph rather than to the site icon, so a cover is
                            // never substituted for.
                            Image {
                                id: thumb

                                // Quickshell surfaces the art url as a property but
                                // not the page's own, so that comes off the raw
                                // metadata map.
                                readonly property string reported: layout.player?.trackArtUrl ?? ""
                                readonly property string page: layout.player?.metadata?.["xesam:url"] ?? ""

                                // What identifies the track itself, so a cover can
                                // be held for as long as one is playing. The id is
                                // the reliable part; the title stands in for
                                // players that reuse a single object path, which
                                // Firefox does for every tab it plays.
                                readonly property string track: (layout.player?.metadata?.["mpris:trackid"] ?? "") + "\n" + (layout.player?.trackTitle ?? "")

                                // The cover, held across the updates that omit it.
                                //
                                // Firefox writes the art to a file and only names
                                // it in some of its metadata emissions: most carry
                                // the same track with no artUrl at all, so reading
                                // the property directly drops the cover a second or
                                // two in and never gets it back. Latched until the
                                // track changes, which is the only point the art is
                                // genuinely stale.
                                property string cover: ""

                                // The track the latched cover belongs to, so it is
                                // released for a new one rather than carried over.
                                // Held alongside the url instead of clearing on a
                                // track change, since the title and the art arrive
                                // in separate updates and in no fixed order: a
                                // handler that cleared on one would race the other.
                                property string coverTrack: ""

                                function latch() {
                                    if (reported !== "") {
                                        cover = reported;
                                        coverTrack = track;
                                    } else if (track !== coverTrack) {
                                        // a different track, and nothing published
                                        // for it yet
                                        cover = "";
                                        coverTrack = "";
                                    }
                                }

                                onReportedChanged: latch()
                                onTrackChanged: latch()

                                // The handlers only run on a change, so a player
                                // already playing when this is built would other-
                                // wise start with nothing latched.
                                Component.onCompleted: latch()

                                // Which tier is being drawn. Decided on whether the
                                // player published art at all, not on whether that
                                // art loaded: a player that named a cover is
                                // showing that cover or nothing, and standing a
                                // site icon in for one that failed would put the
                                // wrong picture against the track.
                                //
                                // Kept as its own property rather than read back
                                // off source, which Qt resolves to an absolute url
                                // that no longer matches the raw string.
                                readonly property bool showingCover: cover !== ""

                                anchors.centerIn: parent

                                // The cover fills the square; a site icon is 16 to
                                // 32 pixels and sits at its own size instead, as a
                                // badge. Enlarging one to the full tile would only
                                // show its resampling.
                                width: showingCover ? parent.width : 22
                                height: showingCover ? parent.height : 22

                                // Cover art is the record and turns with it. A
                                // site icon is not: it is a stand in for art
                                // that does not exist, and spinning a logo
                                // reads as a glitch rather than as a record.
                                // Turned back by the same angle so it sits
                                // still while the disc moves under it.
                                rotation: showingCover ? 0 : -art.spin

                                // The site icon is only ever asked for when there is
                                // no cover at all, so a player with artwork never
                                // causes a request. It stays empty until the fetch
                                // lands, which is what leaves the glyph showing in
                                // the meantime.
                                source: showingCover ? cover : Favicons.forUrl(page)

                                fillMode: showingCover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                mipmap: !showingCover

                                // Decoded at device resolution, like the tray
                                // icons: without this Qt rescales from whatever the
                                // file happens to be.
                                sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                                sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
                            }

                            // Shows through when there is nothing to draw: no
                            // cover, and no icon for the site either. An empty
                            // square reads as something missing rather than as a
                            // track without a cover.
                            Shape {
                                anchors.centerIn: parent
                                implicitWidth: 18
                                implicitHeight: 18
                                preferredRendererType: Shape.CurveRenderer
                                visible: thumb.status !== Image.Ready
                                opacity: 0.7

                                // Held upright like the site icon: standing in
                                // for missing art, not art itself.
                                rotation: -art.spin

                                // A quaver, as one outline: up the stem, out along
                                // the flag and back under it, then down to the
                                // foot. Drawn with width rather than as a stroked
                                // line, which fills nothing.
                                ShapePath {
                                    fillColor: Theme.overlay0
                                    strokeColor: "transparent"

                                    PathSvg {
                                        path: "M 6.6 12.6 L 6.6 3.4 L 14.6 1.2 L 14.6 3.9 L 8.4 5.6 L 8.4 12.6 Z"
                                    }
                                }

                                // the head, sitting at the foot of the stem
                                ShapePath {
                                    fillColor: Theme.overlay0
                                    strokeColor: "transparent"

                                    PathAngleArc {
                                        centerX: 4.9
                                        centerY: 13.1
                                        radiusX: 3.1
                                        radiusY: 2.5
                                        startAngle: 0
                                        sweepAngle: 360
                                    }
                                }
                            }
                        }

                        // The rim, around the record rather than over it: the
                        // border is drawn inward from these bounds, and these
                        // bounds are the full tile, so it fills the gap the
                        // disc was inset to leave.
                        Rectangle {
                            id: rim

                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: art.rim
                            border.color: art.accent

                            // Eased so a track change settles into the new
                            // sleeve's colour rather than cutting to it.
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.fadeDuration
                                }
                            }
                        }

                        // Cast by the rim, which is the record's outer edge:
                        // the disc inside it is inset, so a shadow taken from
                        // that would sit under the rim rather than around the
                        // whole thing.
                        //
                        // Sits behind both, since it is drawn at z -1 and the
                        // rim is the last thing in the tile.
                        DropShadow {
                            target: rim
                            elevation: 5
                            strength: 0.4
                        }
                    }

                    Column {
                        width: parent.width - art.width - parent.spacing
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

                        // Transport and scrub on one line: the card has room
                        // for three rows and the title and artist take two, so
                        // the bar shares the buttons' line rather than forcing
                        // a taller card.
                        Item {
                            width: parent.width
                            implicitHeight: 21

                            Row {
                                id: transport

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

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

                            // Where the track has got to, and a way to move it.
                            //
                            // Only up for a player that reports both a length
                            // and a position: without either there is nothing
                            // to draw a proportion from, and a bar stuck at
                            // zero reads as a stalled track.
                            Item {
                                id: scrub

                                readonly property real length: layout.player?.length ?? 0
                                readonly property bool has: (layout.player?.lengthSupported ?? false) && (layout.player?.positionSupported ?? false) && length > 0

                                // Held while dragging so the bar follows the
                                // pointer rather than the position still
                                // arriving from the player, which would fight
                                // it back to where the track actually is.
                                property real held: 0
                                property bool seeking: false

                                readonly property real at: seeking ? held : Math.max(0, Math.min(length, layout.player?.position ?? 0))
                                readonly property real fraction: length > 0 ? at / length : 0

                                anchors.left: transport.right
                                anchors.leftMargin: Theme.spaceSm
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height
                                visible: has

                                // Position is not pushed during playback, only
                                // on a seek, so it is re-read on a tick to
                                // advance the bar. Stopped whenever the card is
                                // not up or nothing is playing, so a closed
                                // panel is not waking to poll the bus.
                                Timer {
                                    running: scrub.has && root.shown && (layout.player?.isPlaying ?? false) && !scrub.seeking
                                    interval: 1000
                                    repeat: true
                                    onTriggered: {
                                        if (layout.player)
                                            layout.player.positionChanged();
                                    }
                                }

                                Rectangle {
                                    id: scrubTrack

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: Theme.barThickness
                                    radius: height / 2
                                    color: Qt.alpha(Theme.surface2, 0.55)

                                    Rectangle {
                                        width: Math.max(0, Math.min(1, scrub.fraction) * parent.width)
                                        height: parent.height
                                        radius: parent.radius
                                        color: scrubHover.hovered || scrub.seeking ? Theme.text : Theme.subtext0

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 160
                                            }
                                        }

                                        // Followed straight while being
                                        // dragged, and eased otherwise so the
                                        // once a second tick does not step.
                                        Behavior on width {
                                            enabled: !scrub.seeking
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutQuint
                                            }
                                        }
                                    }
                                }

                                // Seeking is not always offered even when a
                                // position is: a live stream reports where it
                                // is without letting you move it.
                                readonly property bool canSeek: layout.player?.canSeek ?? false

                                // Seconds rather than a pixel, so the drag can
                                // commit what it was already holding without
                                // converting back through the width.
                                function seekTo(seconds) {
                                    if (!canSeek || length <= 0)
                                        return;
                                    layout.player.position = Math.max(0, Math.min(length, seconds));
                                }

                                function seekToX(x) {
                                    seekTo(Math.max(0, Math.min(1, x / width)) * length);
                                }

                                HoverHandler {
                                    id: scrubHover
                                    enabled: scrub.canSeek
                                    cursorShape: Qt.PointingHandCursor
                                    onHoveredChanged: root.setChildHovered(hovered)
                                }

                                DragHandler {
                                    id: scrubDrag

                                    enabled: scrub.canSeek
                                    target: null
                                    xAxis.enabled: true
                                    yAxis.enabled: false

                                    onActiveChanged: {
                                        if (active) {
                                            scrub.seeking = true;
                                        } else {
                                            scrub.seekTo(scrub.held);
                                            scrub.seeking = false;
                                        }
                                    }

                                    onCentroidChanged: {
                                        if (active)
                                            scrub.held = Math.max(0, Math.min(1, centroid.position.x / scrub.width)) * scrub.length;
                                    }
                                }

                                TapHandler {
                                    enabled: scrub.canSeek
                                    onTapped: eventPoint => scrub.seekToX(eventPoint.position.x)
                                }
                            }
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
                        onTapped: root.clearNotifications()
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
        target: media
        index: 3
        shown: root.shown
        fromRight: root.anchorRight
    }

    // A step later when the media card is there to take the one before it, so
    // the row keeps its place in the sequence either way.
    RevealSlide {
        target: utility
        index: layout.player !== null ? 4 : 3
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

            // Driven low while the stack is being cleared as well as when the
            // panel closes, so the cards leave the way they arrived rather
            // than the model emptying out from under them.
            RevealSlide {
                target: card
                index: layout.rows + card.index
                shown: root.shown && !root.clearing
                fromRight: root.anchorRight

                // Sequenced only when the stack is being cleared, and from the
                // bottom up: the panel's own dismissal takes them together, but
                // clearing happens with the panel still open and reads better
                // as the stack emptying than as everything going at once.
                staggerExit: root.clearing
                exitIndex: Notifications.count - 1 - card.index
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

            // the reveal starts itself; only the blur needs registering
            Component.onCompleted: root.detachedRegions.push(cardRegion)
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
