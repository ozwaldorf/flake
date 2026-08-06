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

    // Held false while the card is fading, so the blur is not left up as a
    // pane around something that is no longer drawn.
    property bool active: true

    visible: false

    readonly property point origin: {
        let x = 0;
        let y = 0;
        let item = target;
        while (item && item !== host.contentItem) {
            x += item.x;
            y += item.y;
            item = item.parent;
        }
        return Qt.point(x, y);
    }

    readonly property Region region: Region {
        x: root.origin.x
        y: root.origin.y
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
