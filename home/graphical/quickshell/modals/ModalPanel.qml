import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import ".."

// Shared chrome for the popup modals: blurred panel that slides out from the
// rail, holding whatever extends it.
PanelWindow {
    id: root

    required property var modelData

    // matches the bar: when the rail is on the right edge, the panel opens
    // leftward so it stays on screen
    required property bool anchorRight

    property bool shown: false

    // Cards over the desktop rather than on a surface of their own. Each one
    // already carries a fill, so the panel behind them is mostly a container;
    // dropping it leaves them floating.
    property bool floating: true

    // Set by interactive children while the pointer is over them. The panel's
    // own hover surface goes unhovered in that case, so without this the modal
    // would dismiss the moment you reached for anything clickable.
    //
    // Counted rather than a plain bool: moving between adjacent buttons can
    // deliver the exiting one's false after the entering one's true, which
    // would read as leaving the panel.
    property int childHoverCount: 0
    readonly property bool childHovered: childHoverCount > 0

    function setChildHovered(on) {
        childHoverCount = Math.max(0, childHoverCount + (on ? 1 : -1));
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
        interval: Theme.morphDuration + 120
    }

    default property alias content: body.data

    // Items stacked below the panel as their own surfaces rather than inside
    // it, so they are not bounded by the panel's fill or rounding.
    property alias detached: detachedColumn.data

    signal dismissed
    signal hoverChanged(bool hovered)

    screen: modelData
    color: "transparent"
    visible: shown || slide.running

    anchors {
        left: !root.anchorRight
        right: root.anchorRight
        top: true
        bottom: true
    }

    // Room past the panel for what falls outside it: the cards' shadows reach
    // beyond their own edges, and the window is what they are clipped to.
    readonly property real shadowRoom: 16

    implicitWidth: Theme.rail + Theme.spaceXs + Theme.modalWidth + shadowRoom
    exclusiveZone: 0

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Bounds of the detached viewport in window coordinates, so detached items
    // can clip their own blur regions to what is actually on screen.
    readonly property real detachedLeft: detachedView.x
    readonly property real detachedTop: detachedView.y
    readonly property real detachedBottom: detachedView.y + detachedView.height

    // how far the stack is scrolled, so detached items can offset their own
    // window space geometry
    readonly property real detachedScroll: detachedView.contentY

    // Total extent of the panel plus anything detached below it, using the
    // viewport height rather than the column's so the mask and hover surface
    // stop where the visible stack does.
    readonly property real stackHeight: panel.height + (detachedView.height > 0 ? Theme.spaceSm + detachedView.height : 0)

    // only the panel takes pointer input; the strip over the rail stays click
    // through so the bar keeps its own hover and tap handling. The region
    // starts at the rail edge so travelling the gap does not drop the hover.

    mask: Region {
        x: root.anchorRight ? panel.x : Theme.rail
        y: panel.y
        width: panel.width + Theme.spaceXs
        height: root.stackHeight
    }

    Rectangle {
        id: panel

        readonly property real maxHeight: root.height - 20

        // opens inward from whichever edge the rail is on
        x: root.anchorRight ? 0 : Theme.rail + Theme.spaceXs
        y: 10
        width: Theme.modalWidth
        // sized to content when the panel reports one, capped to the screen
        height: root.contentHeight > 0 ? Math.min(root.contentHeight, maxHeight) : maxHeight

        // Without a surface of its own the panel is just a column of cards
        // over the desktop, each carrying its own fill and blur.
        radius: Theme.rounding
        color: root.floating ? "transparent" : Theme.surfaceFill
        border.width: root.floating ? 0 : 1
        border.color: Theme.surface1

        // Fade only: no scale, no position or size animation.
        //
        // While floating the panel draws nothing of its own, and its rows fade
        // themselves on a stagger, so applying this to them as well would
        // compound the two. It stays as the timing signal the blur and the
        // window's own visibility key off.
        opacity: root.floating ? 1 : fade

        // not readonly: a Behavior writes to what it animates
        property real fade: root.shown ? 1 : 0

        Behavior on fade {
            NumberAnimation {
                id: slide
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuint
            }
        }


        Item {
            id: body

            anchors.fill: parent
        }

    }

    // shape the viewport is masked to; matches the cards' own rounding
    Item {
        id: viewportMask

        width: detachedView.width
        height: detachedView.height
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding
            color: "black"
        }
    }

    // Detached surfaces, stacked under the panel with the same left edge.
    // Viewport for the detached stack, capped to whatever room is left below
    // the panel so a long list scrolls instead of running off screen.
    Flickable {
        id: detachedView

        x: panel.x
        y: panel.y + panel.height + Theme.spaceSm
        width: panel.width
        height: Math.min(detachedColumn.height, root.height - y - 10)

        contentHeight: detachedColumn.height
        contentWidth: width
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        // Rounded clip rather than Flickable's own clip, which is a rectangular
        // scissor and squares off cards at the scroll edges.
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: viewportMask
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AlwaysOff
        }

        Column {
            id: detachedColumn

            width: parent.width
            spacing: Theme.spaceSm

            // Not bound to panel.opacity: the cards fade individually on a stagger
            // so they arrive one after another below the panel.
            opacity: 1

            // A new card slides down into place from under the panel rather than
            // appearing where it lands; the ones below it shuffle down to make room.
            add: Transition {
                // y is column local, so starting at 0 means sliding down from the
                // panel's lower edge into whatever slot the card lands in
                // position only: the card drives its own opacity so the staggered
                // reveal is not fought by a second animator here
                NumberAnimation {
                    properties: "y"
                    from: 0
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }

            // Positioners have no displaced transition; move covers both reordering
            // and shuffling to make room for an insert or removal.
            move: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
        }
    }

    // Hover surface behind the content, spanning the panel plus the gap back to
    // the rail so travelling between them never registers as leaving.
    //
    // It sits behind rather than in front: an overlay would swallow the
    // children's own hover state, killing their highlights and cursors. The
    // cost is that this handler reports unhovered whenever a child takes the
    // pointer, so childHovered feeds back in to keep the panel open.
    Item {
        id: hoverSurface

        x: root.anchorRight ? panel.x : Theme.rail
        y: panel.y
        width: panel.width + Theme.spaceXs
        height: root.stackHeight
        z: -1

        HoverHandler {
            id: surfaceHover
        }
    }

    // true while the pointer is anywhere over the panel, whether that is the
    // bare surface or one of its interactive children, and held true across a
    // resize so the settling geometry cannot dismiss it
    readonly property bool pointerInside: surfaceHover.hovered || childHovered || resizeGrace.running

    onPointerInsideChanged: root.hoverChanged(pointerInside)

    // Children release their own raises on destruction, which is what keeps
    // this count honest; there is deliberately no watchdog second-guessing it,
    // since nothing here can tell a stale raise from a stationary pointer
    // resting on a row.

    // Client side blur matching the panel exactly, including its corner radius,
    // so the blur does not square off outside the rounded edge.
    //
    // The region is plain geometry and knows nothing about opacity, so leaving
    // it up through the fade out reads as a ghost. Rather than animate the
    // geometry, switch it at the halfway point of the fade: the panel is
    // translucent enough either side of that for the toggle not to register.
    // Union of the panel and any detached surfaces, so each keeps its own
    // rounding rather than one box blurring the gaps between them.
    BackgroundEffect.blurRegion: Region {
        regions: [panelRegion].concat(detachedRegions).concat(cardRegions)
    }

    // populated by detached items that want their own blur
    property list<Region> detachedRegions

    // Populated by the cards inside the panel. With no surface of its own the
    // panel blurs nothing, so each card frosts its own rectangle instead and
    // the gaps between them stay clear.
    property list<Region> cardRegions

    // Switched at the halfway point of the fade, which every surface here
    // keys off: a region is plain geometry and knows nothing about opacity, so
    // holding one to the end of the fade leaves a pane where the panel was.
    readonly property bool blurActive: panel.fade > 0.5

    Region {
        id: panelRegion

        // Nothing to blur behind a panel that is not drawing a surface: the
        // cards over it carry their own, and blurring the gaps between them
        // would show as a pane hanging around them.
        readonly property bool active: root.blurActive && !root.floating

        x: panel.x
        y: panel.y
        width: active ? panel.width : 0
        height: active ? panel.height : 0
        radius: Theme.rounding
    }
}
