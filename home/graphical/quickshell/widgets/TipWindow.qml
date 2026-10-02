import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// A tooltip beside the rail, opened by hovering one of its marks. Its own layer
// surface rather than an item in the bar: the bar's window is only as wide as
// the rail and masked to it, so anything drawn beside it would be clipped.
EdgeWindow {
    id: root

    // vertical centre of the mark this is describing, in window coordinates
    property real markY: 0

    property bool shown: false

    // How long the window stays mapped after shown drops, so the content's
    // own fade out has a surface to run on.
    property int settleTime: Theme.morphDuration

    // where the content sits across the window: beside the rail, inward
    readonly property real contentX: anchorRight ? shadowRoom : Theme.rail + Theme.spaceXs

    // Level with the mark, held inside the screen so a mark near either edge
    // does not push the content off it.
    function placeY(contentHeight) {
        return Math.round(Math.min(height - contentHeight - 10, Math.max(10, markY - contentHeight / 2)));
    }

    visible: shown || settling.running

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the mark it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    Timer {
        id: settling
        interval: root.settleTime
    }

    onShownChanged: {
        if (!shown)
            settling.restart();
    }

    // Populated by the content's own CardBlur, so the window blurs each card
    // rather than one box covering the gaps between them.
    //
    // Starts with a rectangle of no size, which is never removed. A union with
    // nothing contributing to it falls back to covering the item it belongs
    // to, and here that is a window the height of the screen: every card's
    // region is empty until it is halfway through its fade, so on the way in
    // the whole window would blur for those frames.
    property list<Region> cardRegions: [
        Region {
            width: 0
            height: 0
        }
    ]

    BackgroundEffect.blurRegion: Region {
        width: 0
        height: 0
        regions: root.cardRegions
    }
}
