import QtQuick
import ".."

// The surface every card in the panels stands on. Over the desktop it is
// raised: the shared translucent fill, frosted behind when a host window
// collects blur regions, lifted under the pointer. In a drawer behind the
// desktop it is a well cut into the drawer instead, with nothing to blur and
// nowhere to lift to.
Rectangle {
    id: root

    // window collecting the blur regions; null leaves the card unfrosted
    property var host: null

    // Recessed when the window it stands in is a drawer, which says so; a
    // card with no host, or one over the desktop, stays raised.
    property bool recessed: host?.recessed ?? false

    // whether the card lifts under the pointer at all
    property bool lifts: true

    // Over the card or anything in it: the handler sits on the card itself,
    // so a child taking the pointer does not read as leaving.
    readonly property bool hovered: cardHover.hovered
    readonly property bool lifted: lifts && hovered

    property int cursorShape: Qt.ArrowCursor

    radius: Theme.cardRadius
    color: recessed ? (lifted ? Theme.wellRaised : Theme.wellFill) : (lifted ? Theme.surfaceRaised : Theme.surfaceFill)

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverDuration
        }
    }

    Loader {
        active: root.host !== null && !root.recessed
        sourceComponent: CardBlur {
            target: root
            host: root.host
        }
    }

    Inset {
        target: root
        visible: root.recessed
    }

    // lifts a little under the pointer, so the card reads as coming forward
    // rather than only changing colour
    DropShadow {
        target: root
        visible: !root.recessed
        elevation: root.lifted ? 9 : 6
        strength: root.lifted ? 0.45 : 0.35
    }

    HoverHandler {
        id: cardHover
        cursorShape: root.cursorShape
    }
}
