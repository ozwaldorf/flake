import QtQuick
import Quickshell
import ".."

// Registers a card's rectangle with the window's blur, so a card standing on
// the desktop rather than on a panel is frosted behind rather than merely
// translucent.
//
// Dropped in beside the card's content: it takes the card as its target and
// walks up to the window itself, since the blur region is declared in window
// coordinates. Walked in a binding rather than read from mapToItem, which is a
// one shot call with no dependency tracking and would leave the region behind
// as soon as the card moved or its column scrolled.
Item {
    id: root

    // the card being blurred, and the window collecting the regions
    required property Item target
    required property var host

    // Switched at the halfway point of the card's own fade, not the panel's:
    // the rows arrive on a stagger, so a row still waiting its turn would have
    // its blur snap on at full size while it was invisible.
    //
    // A region is plain geometry and knows nothing about opacity, so it cannot
    // fade with the card; the card is translucent enough either side of
    // halfway for the switch not to register.
    //
    // Compounded up the chain rather than read off the target: a card inside a
    // row that fades as a whole has an opacity of its own that never moves, so
    // the fade it is actually subject to belongs to something above it.
    property bool active: chain.opacity > 0.5

    visible: false

    // One walk for both: the offset from the window's origin and the opacity
    // the card is actually drawn at. Every step's x, y and opacity is read, so
    // each is a dependency and the region follows the card as it slides in.
    readonly property var chain: {
        let x = 0;
        let y = 0;
        let o = 1;
        let item = target;
        while (item && item !== host.contentItem) {
            x += item.x;
            y += item.y;
            o *= item.opacity;
            item = item.parent;
        }
        return {
            x: x,
            y: y,
            opacity: o
        };
    }

    readonly property Region region: Region {
        x: root.chain.x
        y: root.chain.y
        width: root.active && root.target.visible ? root.target.width : 0
        height: root.active && root.target.visible ? root.target.height : 0
        radius: root.target.radius ?? 9
    }

    Component.onCompleted: host.cardRegions.push(region)

    Component.onDestruction: {
        const i = host.cardRegions.indexOf(region);
        if (i >= 0)
            host.cardRegions.splice(i, 1);
    }
}
