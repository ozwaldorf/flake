pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import ".."
import "../services"

// Now playing, as a card like the levels above it. Rendered identically
// whether it sits in the control centre or pops as a toast on a track change;
// the only difference is where it is loaded and what drives its blur.
Rectangle {
    id: root

    // the Mpris player being drawn, or null
    required property var player

    // the window collecting blur regions, and whether the card is on screen:
    // the position timer only ticks while it is
    required property var host
    property bool live: true

    // Raised while the card or one of its controls has the pointer, so a
    // containing panel can tell the pointer has not left it. Counted here so
    // every raise can be released on destruction, which is what keeps a
    // dismissed card from leaving its host's counter stuck.
    signal childHoverChanged(bool hovered)

    property int hoverRaises: 0

    function raiseHover(on) {
        hoverRaises += on ? 1 : -1;
        childHoverChanged(on);
    }

    Component.onDestruction: {
        while (hoverRaises > 0) {
            hoverRaises--;
            childHoverChanged(false);
        }
    }

    // The sleeve's colour, published so a host can tint around the card.
    readonly property alias accent: art.accent

    // Whether the player offers a way back to itself. Advertised as CanRaise on
    // the bus, and taken at its word: nothing here can tell a player that will
    // honour it from one that will not.
    readonly property bool canRaise: player?.canRaise ?? false

    // Whether the art has settled, for a host that would rather wait than show
    // the card resolving in front of the viewer.
    //
    // A cover is settled once it has both decoded and been quantised: the rim
    // and the wash are taken from the quantiser, so a card shown on the decode
    // alone still visibly re-tints a frame or two later. Every other tier has
    // nothing to wait for. The site icon and the glyph both leave the accent at
    // its fallback, and art that failed is never going to arrive.
    readonly property bool artSettled: art.incomingReady

    implicitHeight: 86
    radius: 9

    color: mediaHover.hovered ? Qt.tint(Theme.surfaceFill, Qt.alpha(Theme.text, 0.06)) : Theme.surfaceFill

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    // The sleeve's colour washing in from the record's side and gone by the
    // middle of the card.
    //
    // Laid over the card's own fill rather than replacing it: a gradient on the
    // rectangle would take the place of the colour the hover tint animates, and
    // the fill is semi transparent over the blur, so an opaque wash here would
    // show as a patch through the frosting. This fades to fully transparent and
    // lets the card show through instead.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius

        // Follows the side the record is on, so the colour comes from the art
        // rather than across the card at it.
        //
        // Held at full strength until just past the record before it starts to
        // go: the art only takes the first quarter of the card, so a fade
        // beginning at the edge is already thinning out behind the art itself.
        // It carries the whole width from there, so the colour runs out at the
        // far edge rather than stopping short and leaving a seam.
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: Qt.alpha(art.accent, 0.28)

                Behavior on color {
                    enabled: art.easeAccent
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
                    enabled: art.easeAccent
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            GradientStop {
                position: 1
                color: Qt.alpha(art.accent, 0)

                Behavior on color {
                    enabled: art.easeAccent
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }
        }
    }

    CardBlur {
        target: root
        host: root.host
    }

    DropShadow {
        target: root
        elevation: mediaHover.hovered ? 9 : 6
        strength: mediaHover.hovered ? 0.45 : 0.35
    }

    // Reported upward like the other cards: the panel dismisses on losing the
    // pointer, and the buttons alone do not cover it.
    HoverHandler {
        id: mediaHover

        // Only where the card itself is the target. The transport and the
        // scrub bar carry their own cursors, and this would otherwise put a
        // pointing hand over a slider that drags.
        cursorShape: root.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor

        onHoveredChanged: root.raiseHover(hovered)
    }

    // The whole card is the way back to the player, rather than the client name
    // alone: the label is nine pixels of text, and what it names is where the
    // entire surface already points.
    //
    // Declared before the content, so it sits below the transport and the
    // scrub bar in stacking order and their handlers take the press first. A
    // tap that lands on a button raises nothing; one anywhere else raises.
    TapHandler {
        // The card is a control surface as much as a link, so this is the left
        // button only: the middle and right are free for whatever a host wants
        // to put on them.
        acceptedButtons: Qt.LeftButton

        // Raised where the player offers it, and acknowledged either way: a
        // host that puts itself away behind the tap should do so whether or
        // not there was somewhere to go.
        onTapped: {
            if (root.canRaise)
                root.player.raise();
            root.tapped();
        }
    }

    // Emitted when the card has been tapped anywhere that is not one of its own
    // controls, so a host that is only up transiently can put itself away.
    signal tapped

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceSm

        // The art as a record: round, turning while the track plays and holding
        // its angle when it stops.
        //
        // Sized on the card's inner height, so it grows with the card rather
        // than sitting in it at a fixed size.
        Item {
            id: art

            width: parent.height
            height: parent.height

            // How thick the rim is, and so how far the record is inset from the
            // tile to leave room for it. Qt draws a border inward from the
            // bounds, so a rim on the disc itself would be laid over the art
            // rather than around it; the ring is its own circle and the disc
            // shrinks to sit inside it.
            readonly property real rim: 3

            // The record's own colour, taken from the art so the rim carries
            // the sleeve rather than one grey for everything.
            //
            // Quantised over the whole image: a handful of colours by median
            // cut, and the one with the most life in it wins. Falls back to the
            // plain rim while there is no art, or none that yields a usable
            // colour.
            ColorQuantizer {
                id: sleeve

                // Only asked for once there is a cover: the site icon is a logo
                // rather than art, and colouring the record by it says nothing
                // about the track.
                source: thumb.showingCover ? thumb.source : ""

                // Four levels, so sixteen buckets: enough to separate a
                // sleeve's few real colours without splitting them into near
                // duplicates.
                depth: 4

                // Sampled small; the dominant colour of a cover does not need
                // every pixel to find.
                rescaleSize: 64
            }

            readonly property color fallbackAccent: Qt.alpha(Theme.crust, 0.55)

            // The colour actually drawn, held across the gap between one cover
            // and the next.
            //
            // The quantiser empties the moment its source changes and only
            // refills once the new cover has decoded, so a rim bound straight
            // to the reading drops to the fallback in between and eases back up
            // through grey on every track change. Latching means the card is
            // already wearing the outgoing colour when it goes, and steps
            // straight to the incoming one.
            //
            // Seeded rather than left transparent so a card built against a
            // cover still loading starts at the plain rim.
            property color accent: fallbackAccent

            // Whether a change to the accent should be eased.
            //
            // The first colour a track gets is not a transition from anything:
            // the card is either arriving with it or has been sitting on the
            // track before's colour while the new cover loaded. Easing there
            // plays that stale colour as if it meant something. Later changes
            // within the same track are a genuine correction, and those ease.
            property bool easeAccent: false

            // Cleared on the way to a new track so its first colour lands flat,
            // and set again once that colour is in.
            readonly property string forTrack: thumb.track

            onForTrackChanged: easeAccent = false

            // ---- presenting the art and its colour together ----
            //
            // The loader decodes and the quantiser reads it, each finishing when
            // it finishes. Committing on either one alone is what showed the art
            // appearing first and the colour arriving after it: they are two
            // readings of the same picture, so they are presented as one.

            // The two crossfading layers, by index, and which of them is on top.
            property var layers: [null, null]
            property int incomingLayer: 0

            // What is actually presented, as opposed to what the loader holds.
            // The tier is committed alongside the art, so the layers do not
            // resize to a site icon's badge while still drawing a cover.
            property bool shownCover: false
            property bool hasArt: false

            // Ready when the picture and its colour both are. A site icon or a
            // failure has no colour to wait for and commits on the decode alone.
            readonly property bool incomingReady: {
                // A track that has changed but not yet said what its art is.
                // The tier falls back to the site icon in the meantime, which
                // is usually already cached and so decodes at once: committing
                // on it flashes a favicon in the gap before the real cover
                // lands. The old art is the better thing to hold until then.
                if (thumb.awaitingArt)
                    return false;

                // Nothing named for this track: the glyph is the presentation,
                // and there is nothing further to wait for.
                if (thumb.source == "")
                    return true;
                if (thumb.status === Image.Error)
                    return true;
                if (thumb.status !== Image.Ready)
                    return false;
                return !thumb.showingCover || sleeve.colors.length > 0;
            }

            onIncomingReadyChanged: commit()
            onReadingChanged: commit()

            // Everything the new track brings, applied in one go: the art swaps
            // to the layer fading in, the tier follows it, and the colour is
            // written in the same pass. Guarded on the source rather than the
            // colour, so a sleeve whose colour happens to match the last one
            // still swaps the picture.
            function commit() {
                if (!incomingReady)
                    return;

                const front = layers[incomingLayer];
                const back = layers[1 - incomingLayer];
                if (!front || !back)
                    return;

                // Already presenting this exact art: only the colour can have
                // moved, which is a correction rather than a new picture.
                if (front.source == thumb.source) {
                    accent = reading;
                    easeAccent = true;
                    return;
                }

                // Loaded underneath before being raised, so the layer coming up
                // is never blank for a frame.
                back.cover = thumb.showingCover;
                back.source = thumb.source;
                shownCover = thumb.showingCover;
                hasArt = thumb.status === Image.Ready;
                accent = reading;

                incomingLayer = 1 - incomingLayer;

                // Crossed only when there was something there to cross from;
                // the first art a card shows has nothing underneath it.
                back.raise(easeAccent && front.source != "");
                easeAccent = true;
            }

            // The outgoing layer, once the incoming one has fully covered it.
            // Cleared rather than left drawing: two decoded covers held per card
            // is the cost of the crossfade, and only one of them is visible.
            function settleLayers() {
                const back = layers[1 - incomingLayer];
                if (!back)
                    return;
                back.opacity = 0;
                back.source = "";
            }

            // The most saturated of the quantised colours, kept clear of the
            // ends: a sleeve's average tends to mud, and near black or near
            // white carries no hue to speak of. Falls back to the flat rim when
            // nothing qualifies.
            readonly property color reading: {
                const fallback = fallbackAccent;
                const colors = sleeve.colors;
                if (!colors || colors.length === 0)
                    return fallback;

                let best = null;
                let bestScore = 0;

                for (const c of colors) {
                    // Weighted toward saturation but held back from the
                    // extremes of lightness, where a strong reading of hue is
                    // not a strong colour.
                    const room = 1 - Math.abs(c.hsvValue - 0.55) * 1.6;
                    const score = c.hsvSaturation * Math.max(0, room);

                    if (score > bestScore) {
                        bestScore = score;
                        best = c;
                    }
                }

                // Nothing with any colour in it: a greyscale sleeve reads
                // better with the plain rim than with a tinted grey.
                return best && bestScore > 0.05 ? best : fallback;
            }

            // Driven as an angle that only ever increases, rather than a zero to
            // 360 loop: a loop restarts from its "from" every time it runs, so
            // pausing and playing would snap the record back to the top. Each
            // leg starts from wherever the last one was stopped.
            property real spin: 0

            readonly property bool turning: (root.player?.isPlaying ?? false) && root.live

            // one revolution, so the leg length sets the speed
            readonly property int revolution: 8000

            // The from and to are captured when the animation starts and
            // replayed for every loop, so each revolution repeats the same leg.
            // That is seamless only because the leg is exactly 360 degrees: the
            // jump back at the loop boundary is a whole turn, and a whole turn
            // is no turn at all. Any other leg length here would visibly snap.
            NumberAnimation {
                id: spinner

                target: art
                property: "spin"
                from: art.spin
                to: art.spin + 360
                duration: art.revolution
                loops: Animation.Infinite
            }

            // Restarted on each change so the new leg picks up the angle the old
            // one stopped at. Stopping alone leaves spin where it stands, which
            // is the hold.
            onTurningChanged: {
                if (turning)
                    spinner.restart();
                else
                    spinner.stop();
            }

            // The handlers only run on a change, so a card built against a
            // player already playing, or a cover already loaded, would
            // otherwise start stopped and at the seed colour.
            Component.onCompleted: {
                if (turning)
                    spinner.restart();
                commit();
            }

            // Masked rather than clipped. Qt's clip is a rectangular scissor and
            // Image has no radius of its own, so neither rounds a cover: it
            // would sit as a square tile behind a round edge. The mask is the
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

                // Inset by the rim, which is drawn around this rather than over
                // it. The mask is inset to match: it is a texture for exactly
                // these bounds, so the two have to be the same size and place.
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

                // The art, in order of preference: the player's own cover, else
                // the icon of the site it named, else nothing and the glyph
                // below shows through.
                //
                // Resolved to a single source rather than stacked as a layer
                // each: one image exists at a time, so there is no second decode
                // sitting behind the first and no earlier tier showing through a
                // gap in a later one.
                //
                // The choice is made on what the player published, not on what
                // loaded: art that fails falls through to the glyph rather than
                // to the site icon, so a cover is never substituted for.
                //
                // Not drawn itself: this decodes the incoming art and feeds the
                // quantiser, and the two visible layers below take a copy of it
                // once both it and its colour are ready. Presenting straight
                // from here is what made the art appear the instant it decoded
                // and the accent follow separately once quantised.
                Image {
                    id: thumb

                    visible: false

                    // Quickshell surfaces the art url as a property but not the
                    // page's own, so that comes off the raw metadata map.
                    readonly property string reported: root.player?.trackArtUrl ?? ""
                    readonly property string page: root.player?.metadata?.["xesam:url"] ?? ""

                    // What identifies the track itself, so a cover can be held
                    // for as long as one is playing. The id is the reliable
                    // part; the title stands in for players that reuse a single
                    // object path, which Firefox does for every tab it plays.
                    readonly property string track: (root.player?.metadata?.["mpris:trackid"] ?? "") + "\n" + (root.player?.trackTitle ?? "")

                    // The cover, held across the updates that omit it.
                    //
                    // Firefox writes the art to a file and only names it in some
                    // of its metadata emissions: most carry the same track with
                    // no artUrl at all, so reading the property directly drops
                    // the cover a second or two in and never gets it back.
                    // Latched until the track changes, which is the only point
                    // the art is genuinely stale.
                    property string cover: ""

                    // The track the latched cover belongs to, so it is released
                    // for a new one rather than carried over. Held alongside the
                    // url instead of clearing on a track change, since the title
                    // and the art arrive in separate updates and in no fixed
                    // order: a handler that cleared on one would race the other.
                    property string coverTrack: ""

                    // Set while a new track has not yet said what its art is, so
                    // the presentation can hold the old picture rather than
                    // commit the site icon the tier falls back to. Cleared as
                    // soon as a cover is named, or once the wait has gone on
                    // long enough that none is coming.
                    property bool awaitingArt: false

                    Timer {
                        id: artGrace

                        // Long enough for a player to follow a metadata update
                        // with the art it belongs to, which is a beat later at
                        // most; past that the track simply has none.
                        interval: 600

                        onTriggered: thumb.awaitingArt = false
                    }

                    function latch() {
                        if (reported !== "") {
                            cover = reported;
                            coverTrack = track;
                            awaitingArt = false;
                            artGrace.stop();
                        } else if (track !== coverTrack) {
                            // a different track, and nothing published for it yet
                            cover = "";
                            coverTrack = "";
                            awaitingArt = true;
                            artGrace.restart();
                        }
                    }

                    onReportedChanged: latch()
                    onTrackChanged: latch()

                    // The handlers only run on a change, so a player already
                    // playing when this is built would otherwise start with
                    // nothing latched.
                    Component.onCompleted: latch()

                    // Which tier is being drawn. Decided on whether the player
                    // published art at all, not on whether that art loaded: a
                    // player that named a cover is showing that cover or
                    // nothing, and standing a site icon in for one that failed
                    // would put the wrong picture against the track.
                    //
                    // Kept as its own property rather than read back off source,
                    // which Qt resolves to an absolute url that no longer
                    // matches the raw string.
                    readonly property bool showingCover: cover !== ""

                    anchors.centerIn: parent

                    // The cover fills the square; a site icon is 16 to 32 pixels
                    // and sits at its own size instead, as a badge. Enlarging one
                    // to the full tile would only show its resampling.
                    width: showingCover ? parent.width : 22
                    height: showingCover ? parent.height : 22

                    // Cover art is the record and turns with it. A site icon is
                    // not: it is a stand in for art that does not exist, and
                    // spinning a logo reads as a glitch rather than as a record.
                    // Turned back by the same angle so it sits still while the
                    // disc moves under it.
                    rotation: showingCover ? 0 : -art.spin

                    // The site icon is only ever asked for when there is no
                    // cover at all, so a player with artwork never causes a
                    // request. It stays empty until the fetch lands, which is
                    // what leaves the glyph showing in the meantime.
                    source: showingCover ? cover : Favicons.forUrl(page)

                    fillMode: showingCover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: !showingCover

                    // Decoded at device resolution, like the tray icons: without
                    // this Qt rescales from whatever the file happens to be.
                    sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                    sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
                }

                // The two presented layers. One holds what is on screen and the
                // other fades in over it, then they swap roles: a single image
                // cannot cross fade with itself, since changing its source
                // replaces what it was drawing.
                //
                // Both take their geometry from the loader, so a cover and a
                // site icon each present at their own size.
                Repeater {
                    model: 2

                    Image {
                        id: layer

                        required property int index

                        readonly property bool incoming: index === art.incomingLayer

                        // The tier this layer is drawing, committed with its
                        // source rather than read off the shared flag: a cover
                        // crossing with a site icon are different sizes, and one
                        // flag would resize the outgoing one mid fade.
                        property bool cover: false

                        anchors.centerIn: parent

                        width: cover ? parent.width : 22
                        height: cover ? parent.height : 22

                        // Cover art is the record and turns with it. A site icon
                        // is not: it is a stand in for art that does not exist,
                        // and spinning a logo reads as a glitch rather than as a
                        // record. Turned back by the same angle so it sits still
                        // while the disc moves under it.
                        rotation: cover ? 0 : -art.spin

                        // Committed by the swap rather than bound to the loader,
                        // which is what holds the outgoing art up until the new
                        // one is ready to take its place.
                        source: ""

                        fillMode: cover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: false
                        smooth: true
                        mipmap: !cover
                        cache: true

                        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio)
                        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)

                        // The incoming layer rises over the outgoing one, which
                        // stays fully opaque underneath the whole way.
                        //
                        // Driven by the commit rather than bound to which layer
                        // is incoming. A binding animates both at once, which
                        // leaves them each partly transparent through the middle
                        // of the crossing: the disc shows between them and the
                        // art visibly dims, then recovers as the incoming one
                        // lands. Only the one coming up is ever animated, and
                        // the one underneath is dropped outright once it is
                        // covered, where there is nothing left to see.
                        z: incoming ? 1 : 0

                        opacity: 0

                        NumberAnimation {
                            id: rise

                            target: layer
                            property: "opacity"
                            to: 1
                            duration: Theme.fadeDuration
                            easing.type: Easing.OutQuad

                            onFinished: art.settleLayers()
                        }

                        // Raised without a fade for the first art a card ever
                        // shows: there is nothing underneath to cross from.
                        function raise(animated) {
                            if (!animated) {
                                opacity = 1;
                                art.settleLayers();
                                return;
                            }
                            rise.restart();
                        }

                        Component.onCompleted: art.layers[index] = layer
                    }
                }

                // Shows through when there is nothing to draw: no cover, and no
                // icon for the site either. An empty square reads as something
                // missing rather than as a track without a cover.
                Shape {
                    anchors.centerIn: parent
                    implicitWidth: 18
                    implicitHeight: 18
                    preferredRendererType: Shape.CurveRenderer
                    visible: !art.hasArt
                    opacity: 0.7

                    // Held upright like the site icon: standing in for missing
                    // art, not art itself.
                    rotation: -art.spin

                    // A quaver, as one outline: up the stem, out along the flag
                    // and back under it, then down to the foot. Drawn with width
                    // rather than as a stroked line, which fills nothing.
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

            // The rim, around the record rather than over it: the border is
            // drawn inward from these bounds, and these bounds are the full
            // tile, so it fills the gap the disc was inset to leave.
            Rectangle {
                id: rim

                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: art.rim
                border.color: art.accent

                // Eased once the track has a colour, so a cover that updates
                // under it settles rather than cutting. The first colour of a
                // track lands flat: there is nothing meaningful to come from.
                Behavior on border.color {
                    enabled: art.easeAccent
                    ColorAnimation {
                        duration: Theme.fadeDuration
                    }
                }
            }

            // Cast by the rim, which is the record's outer edge: the disc inside
            // it is inset, so a shadow taken from that would sit under the rim
            // rather than around the whole thing.
            //
            // Sits behind both, since it is drawn at z -1 and the rim is the
            // last thing in the tile.
            DropShadow {
                target: rim
                elevation: 5
                strength: 0.4
            }
        }

        Column {
            width: parent.width - art.width - parent.spacing
            spacing: 3

            // Title, with the player it is coming from opposite it.
            //
            // The client is the one thing on the card that is about where the
            // sound is from rather than what it is, so it sits apart from the
            // track's own details and takes the quietest weight on the card.
            Item {
                width: parent.width
                implicitHeight: title.implicitHeight

                Text {
                    id: title

                    // Yields exactly the room the client takes, so a long title
                    // elides against the label rather than running under it.
                    anchors.left: parent.left
                    anchors.right: client.left
                    anchors.rightMargin: client.width > 0 ? Theme.spaceXs : 0

                    text: root.player?.trackTitle ?? ""
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Text {
                    id: client

                    anchors.right: parent.right
                    anchors.baseline: title.baseline

                    // The site when the player names one, else the player.
                    //
                    // A browser is the case this matters for: its identity is
                    // the browser, which says nothing about what is playing,
                    // while the page it is on is the actual source. Anything
                    // that is not a browser publishes no url and keeps its own
                    // name, which is already the right answer for it.
                    //
                    // Parsed by the favicon service rather than here: it
                    // already takes a url off this same bus and validates what
                    // it finds before trusting it.
                    //
                    // Cased down rather than shown as published: players are
                    // not consistent about it, and the label is a note about
                    // the source rather than a proper noun on a card whose
                    // other text is the track's.
                    readonly property string site: Favicons.siteOf(root.player?.metadata?.["xesam:url"] ?? "")

                    text: (site !== "" ? site : (root.player?.identity ?? "")).toLowerCase()

                    font.family: Theme.font
                    font.pixelSize: 9

                    // Lifts with the card's own hover: the whole surface is the
                    // way back to the player, and this names where that goes.
                    color: mediaHover.hovered && root.canRaise ? Theme.subtext0 : Theme.overlay0

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    // Never at the title's expense: it is the lesser of the two,
                    // so it gives way first on a narrow card.
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, parent.width * 0.4)
                }
            }

            Text {
                width: parent.width
                text: root.player?.trackArtist ?? ""
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.overlay0
                elide: Text.ElideRight
            }

            // Transport and scrub on one line: the card has room for three rows
            // and the title and artist take two, so the bar shares the buttons'
            // line rather than forcing a taller card.
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
                        enabled: root.player?.canGoPrevious ?? false
                        onTriggered: root.player.previous()
                        onHoveredChanged: root.raiseHover(hovered)
                    }

                    MediaButton {
                        symbol: root.player?.isPlaying ? "pause" : "play"
                        enabled: root.player?.canTogglePlaying ?? false
                        onTriggered: root.player.togglePlaying()
                        onHoveredChanged: root.raiseHover(hovered)
                    }

                    MediaButton {
                        symbol: "next"
                        enabled: root.player?.canGoNext ?? false
                        onTriggered: root.player.next()
                        onHoveredChanged: root.raiseHover(hovered)
                    }
                }

                // Where the track has got to, and a way to move it.
                //
                // Only up for a player that reports both a length and a
                // position: without either there is nothing to draw a proportion
                // from, and a bar stuck at zero reads as a stalled track.
                Item {
                    id: scrub

                    readonly property real length: root.player?.length ?? 0
                    readonly property bool has: (root.player?.lengthSupported ?? false) && (root.player?.positionSupported ?? false) && length > 0

                    // Held while dragging so the bar follows the pointer rather
                    // than the position still arriving from the player, which
                    // would fight it back to where the track actually is.
                    property real held: 0
                    property bool seeking: false

                    readonly property real at: seeking ? held : Math.max(0, Math.min(length, root.player?.position ?? 0))
                    readonly property real fraction: length > 0 ? at / length : 0

                    anchors.left: transport.right
                    anchors.leftMargin: Theme.spaceSm
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    visible: has

                    // Position is not pushed during playback, only on a seek, so
                    // it is re-read on a tick to advance the bar. Stopped
                    // whenever the card is not up or nothing is playing, so a
                    // closed panel is not waking to poll the bus.
                    Timer {
                        running: scrub.has && root.live && (root.player?.isPlaying ?? false) && !scrub.seeking
                        interval: 1000
                        repeat: true
                        onTriggered: {
                            if (root.player)
                                root.player.positionChanged();
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

                            // Followed straight while being dragged, and eased
                            // otherwise so the once a second tick does not step.
                            Behavior on width {
                                enabled: !scrub.seeking
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutQuint
                                }
                            }
                        }
                    }

                    // Seeking is not always offered even when a position is: a
                    // live stream reports where it is without letting you move
                    // it.
                    readonly property bool canSeek: root.player?.canSeek ?? false

                    // Seconds rather than a pixel, so the drag can commit what it
                    // was already holding without converting back through the
                    // width.
                    function seekTo(seconds) {
                        if (!canSeek || length <= 0)
                            return;
                        root.player.position = Math.max(0, Math.min(length, seconds));
                    }

                    function seekToX(x) {
                        seekTo(Math.max(0, Math.min(1, x / width)) * length);
                    }

                    HoverHandler {
                        id: scrubHover
                        enabled: scrub.canSeek
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: root.raiseHover(hovered)
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
