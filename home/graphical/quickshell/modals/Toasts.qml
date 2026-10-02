pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../widgets"
import "../services"

// Transient popups next to the rail. Critical notifications persist until
// dismissed; everything else times out on its own.
EdgeWindow {
    id: root

    // The bar's own 0 to 1 reveal, so toasts sit against the rail at whatever
    // width it currently is, moving on the rail's clock rather than a second
    // animation of their own that could drift from it.
    required property real barReveal

    readonly property real railGap: 8
    readonly property real railOffset: Theme.sliver + (Theme.rail - Theme.sliver) * barReveal + railGap

    // ---- now playing, popped on a track change ----

    readonly property var player: Media.player

    // What identifies the track, the same key the card's art latches on.
    // Only read while there is a player, so losing one does not read as a
    // change to an empty track and pop a card with nothing in it.
    readonly property string title: player?.trackTitle ?? ""
    readonly property string track: Media.trackKey(player)

    property bool mediaShown: false

    // Held up while the pointer is on it, the way a hovered notification is:
    // the timer only starts counting once the pointer leaves.
    Timer {
        id: mediaTimer
        interval: Theme.toastTimeout
        running: root.mediaShown && !media.hovered
        onTriggered: root.mediaShown = false
    }

    // Covers the card's own way out, so the window is not taken down from
    // under a fade still running. Started on the way down only; the way in is
    // covered by the flag itself.
    Timer {
        id: mediaLeaving
        interval: Theme.morphDuration
    }

    onMediaShownChanged: {
        if (!mediaShown)
            mediaLeaving.restart();
    }

    // Waiting on the art rather than popping a grey card that re-tints a moment
    // later, once the cover has decoded and been quantised. Held as a request
    // that the card itself releases: the art for the new track has usually not
    // even been published yet at this point, let alone loaded.
    property bool mediaPending: false

    // A track with no title is a player that has announced itself but not what
    // it is playing yet, which arrives moments later as the real change. Tested
    // on the title rather than the whole key: the id half is never empty while
    // there is a player, so the pair alone cannot tell the two apart.
    //
    // Suppressed alongside the notification toasts: the control centre carries
    // this same card, so popping a second copy of it beside the panel only
    // duplicates what is already open.
    onTrackChanged: {
        if (title === "" || Notifications.toastsSuppressed)
            return;
        mediaShown = false;
        mediaPending = true;
        artTimeout.restart();
    }

    // Shown the moment the art settles, or without it once the wait has gone on
    // long enough to read as the toast simply not coming: a player that never
    // publishes art would otherwise hold the card back forever.
    readonly property bool artReady: media.artSettled

    onArtReadyChanged: releaseMedia()
    onMediaPendingChanged: releaseMedia()

    function releaseMedia() {
        if (!mediaPending || !artReady)
            return;
        mediaPending = false;
        artTimeout.stop();
        mediaShown = true;
        mediaTimer.restart();
    }

    Timer {
        id: artTimeout

        // Past a moment's wait the art is not coming; the card is worth more
        // with the fallback rim than not at all.
        interval: 1500

        onTriggered: {
            if (!root.mediaPending)
                return;
            root.mediaPending = false;
            root.mediaShown = true;
            mediaTimer.restart();
        }
    }

    // Nothing to keep up once the player is gone, whether it quit or the toast
    // was still counting down when it did.
    onPlayerChanged: {
        if (!player)
            mediaShown = false;
    }

    // Cleared when the panel opens, like the notification stack: the card is in
    // the panel, so leaving the toast up shows it twice.
    Connections {
        target: Notifications

        function onToastsSuppressedChanged() {
            if (Notifications.toastsSuppressed)
                root.mediaShown = false;
        }
    }

    // Held open past the card going down so its fade out has a surface to run
    // on. Read off the flag and a timer rather than the card's own opacity:
    // the card is inside this window, so a visibility bound to it is a loop.
    //
    // Open through the pending wait as well: the card is what loads the art,
    // and it cannot do that inside a window that is not up, so gating this on
    // mediaShown alone would leave it waiting on art that never arrives.
    visible: Notifications.toasts.count > 0 || mediaShown || mediaPending || mediaLeaving.running

    // Fixed at the widest the offset gets, with the stack moving inside it.
    // Sizing the window to the offset would resize it every frame of the
    // rail's travel, and a right anchored surface is repositioned along with
    // it in a separate commit, which shows as the stack shuddering.
    readonly property real maxRailOffset: Theme.rail + railGap

    implicitWidth: maxRailOffset + Theme.modalWidth + shadowRoom

    // Click through everywhere except the toasts themselves. The column rather
    // than each card: the media card collapses to nothing while it is down, so
    // the region follows the stack without it having to be subtracted out.
    mask: Region {
        item: stack
    }

    Column {
        id: stack

        x: root.anchorRight ? root.shadowRoom + root.maxRailOffset - root.railOffset : root.railOffset
        y: 12
        // same width as the control centre cards, so a notification looks
        // identical whether it is a toast or a history entry
        width: Theme.modalWidth
        spacing: Theme.spaceSm

        // surviving toasts slide up when one above them expires rather than
        // snapping to the new position
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }

        // Top of the stack rather than among the notifications: it is one card
        // that comes and goes rather than a queue, and a track change arriving
        // under a stack of toasts would push them down to make room for it.
        //
        // Outside the Repeater and so outside the column's add transition,
        // which is keyed to a batch of arriving notifications; this drives its
        // own reveal instead.
        MediaCard {
            id: media

            width: parent.width
            player: root.player
            host: root

            // Left visible and driven to transparent rather than hidden at
            // rest: an invisible item does not run its transitions, so a
            // visibility keyed to the opacity the transition drives is a
            // deadlock, and the card never fades in at all.
            visible: true

            // Only ticking the position while the card is actually up: off
            // screen it would keep waking to poll the bus for a bar nobody is
            // looking at, and the record would keep turning unseen.
            live: root.mediaShown

            // Collapsed rather than merely transparent while it is down, so it
            // takes no slot in the column and the notifications below sit at
            // the top of the stack rather than under an empty card's worth of
            // space. Animated with the fade, which is what makes them shuffle
            // down to make room rather than jump.
            //
            // Deliberately not clipped: the card's content fills it and so
            // shrinks with it, leaving nothing to spill, while its shadow is
            // drawn outside its own bounds and a clip is exactly what cuts
            // that off.
            opacity: 0
            height: 0

            // In from the rail's side like the notification cards, and back out
            // the same way rather than only fading.
            //
            // The two run as one animation rather than as Behaviors, so the
            // slide cannot be left half done by a change arriving mid fade.
            states: State {
                when: root.mediaShown

                PropertyChanges {
                    media.opacity: 1
                    media.x: 0
                    media.height: media.implicitHeight
                }
            }

            x: root.anchorRight ? Theme.spaceSm : -Theme.spaceSm

            transitions: Transition {
                NumberAnimation {
                    property: "opacity"
                    duration: Theme.fadeDuration
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    properties: "x,height"
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Put away once it has sent the user to the player, rather than on
            // any tap: the card carries a transport and a scrub bar, and a
            // handler of its own out here sits above them and swallows the
            // presses meant for them.
            onTapped: root.mediaShown = false
        }

        // Arriving toasts fade up while sliding in from the rail's side, the
        // way the control centre's rows do. Staggered by position so a burst
        // arrives as a sequence rather than all at once, and overlapping since
        // the step is well inside the fade.
        add: Transition {
            SequentialAnimation {
                // Staggered by position within the batch, so several arriving
                // together come in as a sequence rather than at once. The step
                // is well inside the fade, which keeps them overlapping.
                PauseAnimation {
                    // the index is -1 while the transition is not running
                    // against an item, which the stagger clamps to none
                    duration: Theme.stagger(ViewTransition.index)
                }

                ParallelAnimation {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.fadeDuration
                        easing.type: Easing.OutQuad
                    }

                    // in from the rail's own side, like the panel's rows
                    NumberAnimation {
                        property: "x"
                        from: root.anchorRight ? Theme.spaceSm : -Theme.spaceSm
                        to: 0
                        duration: Theme.morphDuration
                        easing.type: Easing.OutQuint
                    }
                }
            }
        }


        Repeater {
            model: Notifications.toasts

            NotificationCard {
                id: toast

                required property var model

                width: parent.width
                anchorRight: root.anchorRight
                entry: model

                // The column's own transition drives both opacity and x on the
                // way in, so neither is bound here: a binding would be
                // destroyed by the first frame it writes.
                // Whether the card is being cleared rather than left to expire:
                // a tap is the user acting on the notification, so it goes from
                // history too, while a timeout only takes the toast away.
                property bool clearing: false

                // Leaving the same way it arrived rather than vanishing.
                //
                // Run here rather than from a remove transition, which a
                // Column does not have: it is a positioner, not a view. The
                // entry is taken out of the model once the card has gone, so
                // the delegate lives long enough to animate.
                function dismiss(clear) {
                    if (leaving.running)
                        return;
                    toast.clearing = clear ?? false;
                    leaving.start();
                }

                ParallelAnimation {
                    id: leaving

                    onFinished: toast.clearing ? Notifications.remove(toast.model.id) : Notifications.dismiss(toast.model.id)

                    // Short and eased in, so a dismissed toast gets out of the
                    // way and the stack closes up behind it promptly.
                    NumberAnimation {
                        target: toast
                        property: "opacity"
                        to: 0
                        duration: Theme.exitDuration
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: toast
                        property: "x"
                        to: root.anchorRight ? Theme.spaceSm : -Theme.spaceSm
                        duration: Theme.exitDuration
                        easing.type: Easing.InCubic
                    }
                }

                CardBlur {
                    target: toast
                    host: root
                }

                // The app's own timeout wins when it asks for one. Per the
                // freedesktop spec a negative value means it has no preference
                // and zero means never expire, which criticals also get.
                readonly property real requested: toast.model.expireTimeout ?? -1
                readonly property bool persists: toast.critical || requested === 0
                readonly property int lifetime: requested > 0 ? requested * 1000 : Theme.toastTimeout

                Timer {
                    interval: toast.lifetime
                    running: !toast.persists
                    onTriggered: toast.dismiss()
                }

                TapHandler {
                    onTapped: toast.dismiss(true)
                }
            }
        }
    }

    // Registered by each card's own CardBlur: a union of the individual cards
    // rather than one box over the column, which would blur the gaps between
    // them and square off their rounded corners.
    property list<Region> cardRegions

    BackgroundEffect.blurRegion: Region {
        regions: root.cardRegions
    }
}
