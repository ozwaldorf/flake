import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import ".."

// Shared chrome for the popup modals: a column of cards that slides out from
// the rail, holding whatever extends it. The panel draws no surface of its
// own; each card carries its own fill and blur.
EdgeWindow {
    id: root

    property bool shown: false

    // Raised by anything the panel opens as a window of its own, like a tray
    // menu, which this window cannot see the pointer over. Counted, and
    // released by whoever raised it.
    property int holds: 0

    function hold(on) {
        holds = Math.max(0, holds + (on ? 1 : -1));
    }

    // Height of the content, when it can be measured. Panels that fill their
    // body (a scrolling list) leave this at 0 and get the full height instead.
    property real contentHeight: 0

    // A panel that grows or shrinks under a stationary pointer moves its own
    // surface out from under it, and Qt re-evaluates hover against the new
    // geometry before the pointer has gone anywhere. That reads as leaving the
    // panel and dismisses it mid interaction, so hold it open until the
    // geometry has settled. Same problem the rail solves on expand.
    onContentHeightChanged: resizeGrace.restart()

    Timer {
        id: resizeGrace
        interval: Theme.settleDelay
    }

    default property alias content: body.data

    // Items stacked below the panel as their own surfaces rather than inside
    // it, so they are not bounded by the panel's rounding.
    property alias detached: detachedColumn.data

    signal hoverChanged(bool hovered)

    // Mapped for good and switched by its input region instead. A surface
    // mapped as the panel opens takes the pointer for its first frame, before
    // its region has applied, and the rail loses it with nothing to hand it
    // back until the mouse next moves: the corner then reads as left and the
    // panel closes on a pointer that never went anywhere.
    //
    // Nothing is drawn while closed: every row and card has faded to nothing,
    // and their blur regions with them.
    readonly property bool live: shown || fadeAnim.running

    implicitWidth: Theme.rail + Theme.spaceXs + Theme.modalWidth + shadowRoom

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Bounds of the detached viewport in window coordinates, so detached items
    // can clip their own blur regions to what is actually on screen.
    // The cards' own origin, not the viewport's: that reaches past them on
    // every side to give their shadows room, and the column is inset back.
    readonly property real detachedLeft: detachedView.x + detachedColumn.x
    readonly property real detachedTop: detachedView.y + detachedColumn.y
    readonly property real detachedBottom: detachedView.y + detachedView.height

    // how far the stack is scrolled, so detached items can offset their own
    // window space geometry
    readonly property real detachedScroll: detachedView.contentY

    // Total extent of the panel plus anything detached below it, using the
    // viewport height rather than the column's so the mask stops where the
    // visible stack does.
    readonly property real stackHeight: panel.height + (detachedView.height > 0 ? Theme.spaceSm + detachedView.height : 0)

    // Only the panel takes pointer input; the strip over the rail stays click
    // through so the bar keeps its own hover and tap handling. The region
    // starts at the rail edge so travelling the gap does not drop the hover.
    mask: Region {
        x: root.anchorRight ? panel.x : Theme.rail
        y: panel.y
        width: root.live ? panel.width + Theme.spaceXs : 0
        height: root.live ? root.stackHeight : 0
    }

    Item {
        id: panel

        readonly property real maxHeight: root.height - 20

        // Inset from whichever edge the window is anchored to, leaving the
        // shadow room on the outward side: anchored right the window grows
        // leftward, so sitting at nothing puts the free room behind the rail
        // rather than where the shadow falls.
        x: root.anchorRight ? root.shadowRoom : Theme.rail + Theme.spaceXs
        y: 10
        width: Theme.modalWidth
        // sized to content when the panel reports one, capped to the screen
        height: root.contentHeight > 0 ? Math.min(root.contentHeight, maxHeight) : maxHeight

        // The panel's presence as a fade, though nothing draws with it: the
        // rows fade themselves on a stagger. It is the timing the window's own
        // visibility keys off, so the surface outlives the rows going out.
        //
        // not readonly: a Behavior writes to what it animates
        property real fade: root.shown ? 1 : 0

        Behavior on fade {
            NumberAnimation {
                id: fadeAnim
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuint
            }
        }

        Item {
            id: body

            anchors.fill: parent
        }
    }

    // Viewport for the detached stack under the panel, capped to whatever room
    // is left below it so a long list scrolls instead of running off screen.
    Flickable {
        id: detachedView

        // Reaches past the cards on every side, and the column inside is inset
        // back by the same: the clip is to these bounds, so a viewport the
        // width of the cards cuts the shadows they cast.
        x: panel.x - Theme.spaceSm
        y: panel.y + panel.height
        width: panel.width + Theme.spaceSm * 2
        height: Math.min(detachedColumn.height + Theme.spaceSm * 2, root.height - y - 10)

        contentHeight: detachedColumn.height + Theme.spaceSm * 2
        contentWidth: width
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        Column {
            id: detachedColumn

            // inset back to the cards' own width inside a viewport grown to
            // give their shadows room
            x: Theme.spaceSm
            y: Theme.spaceSm
            width: parent.width - Theme.spaceSm * 2
            spacing: Theme.spaceSm

            // A new card slides down into place from under the panel rather
            // than appearing where it lands. Position only: the card drives
            // its own opacity, so the staggered reveal is not fought by a
            // second animator here.
            add: Transition {
                // y is column local, so starting at 0 means sliding down from
                // the panel's lower edge into whatever slot the card lands in
                NumberAnimation {
                    properties: "y"
                    from: 0
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Positioners have no displaced transition; move covers both
            // reordering and shuffling to make room for an insert or removal.
            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
        }
    }

    // On the window itself, so it is the ancestor of every card and control:
    // a hover handler on a parent stays hovered while a child has the pointer,
    // and the mask bounds it to the panel and the gap back to the rail.
    HoverHandler {
        id: surfaceHover
    }

    // true while the pointer is anywhere over the panel or something it
    // opened, and held true across a resize so the settling geometry cannot
    // dismiss it
    readonly property bool pointerInside: surfaceHover.hovered || holds > 0 || resizeGrace.running

    onPointerInsideChanged: root.hoverChanged(pointerInside)

    // Union of the detached surfaces and the cards, so each keeps its own
    // rounding rather than one box blurring the gaps between them.
    //
    // Seeded with a rectangle of no size: a union with nothing contributing
    // to it falls back to covering the whole window.
    BackgroundEffect.blurRegion: Region {
        regions: [seedRegion].concat(root.detachedRegions).concat(root.cardRegions)
    }

    Region {
        id: seedRegion
        width: 0
        height: 0
    }

    // populated by detached items that want their own blur
    property list<Region> detachedRegions

    // Populated by the cards inside the panel. With no surface of its own the
    // panel blurs nothing, so each card frosts its own rectangle instead and
    // the gaps between them stay clear.
    property list<Region> cardRegions
}
