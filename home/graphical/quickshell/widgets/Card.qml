import QtQuick
import ".."

// The surface every card in the panels stands on: the shared fill, frosted
// behind when a host window collects blur regions, lifted under the pointer.
Rectangle {
    id: root

    // window collecting the blur regions; null leaves the card unfrosted
    property var host: null

    // whether the card lifts under the pointer at all
    property bool lifts: true

    // Over the card or anything in it: the handler sits on the card itself,
    // so a child taking the pointer does not read as leaving.
    readonly property bool hovered: cardHover.hovered
    readonly property bool lifted: lifts && hovered

    property int cursorShape: Qt.ArrowCursor

    radius: Theme.cardRadius
    color: lifted ? Theme.surfaceRaised : Theme.surfaceFill

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverDuration
        }
    }

    Loader {
        active: root.host !== null
        sourceComponent: CardBlur {
            target: root
            host: root.host
        }
    }

    // lifts a little under the pointer, so the card reads as coming forward
    // rather than only changing colour
    DropShadow {
        target: root
        elevation: root.lifted ? 9 : 6
        strength: root.lifted ? 0.45 : 0.35
    }

    HoverHandler {
        id: cardHover
        cursorShape: root.cursorShape
    }
}
