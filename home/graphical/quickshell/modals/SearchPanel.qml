pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import ".."
import "../widgets"

// A drawer for picking from a list by typing: a field at the head, the list
// filling the rest, and the keyboard taken while it is out so a keybind can
// open it and go straight to typing. Up and down walk the list, enter takes
// the current entry, escape puts the drawer away.
ModalPanel {
    id: root

    grabsKeyboard: true
    focusTarget: field

    property string placeholder: ""
    property string glyph: ""

    // what the field currently holds, for the panel to filter by
    readonly property alias query: field.text

    // the list as filtered, and what draws each entry
    property var results: []
    property alias delegate: list.delegate

    // an action set at the end of the field, past the count
    property alias trailing: trailingSlot.data

    // keys and what they do, set small under the list
    property string hints: ""

    property alias currentIndex: list.currentIndex
    readonly property var current: results[list.currentIndex] ?? null

    // Whether the pointer has moved since the keyboard last did. Rows coming
    // under a still pointer as the list scrolls would otherwise take the
    // selection back from the keys that scrolled it there.
    property bool pointerLed: false

    signal activated(var result)

    // shift+delete on the current entry
    signal removeRequested(var result)

    function select(index) {
        if (pointerLed)
            list.currentIndex = index;
    }

    function step(by) {
        pointerLed = false;
        if (results.length > 0)
            list.currentIndex = Math.max(0, Math.min(results.length - 1, list.currentIndex + by));
    }

    onQueryChanged: list.currentIndex = 0
    onResultsChanged: list.currentIndex = Math.min(list.currentIndex, Math.max(0, results.length - 1))

    // Fresh each time it comes out, rather than holding whatever was typed
    // into it last.
    onShownChanged: {
        if (!shown)
            return;
        field.text = "";
        list.currentIndex = 0;
        list.positionViewAtBeginning();
        pointerLed = false;
    }

    HoverHandler {
        readonly property point at: point.position
        onAtChanged: root.pointerLed = true
    }

    Rectangle {
        id: search

        width: parent.width
        height: 44
        radius: Theme.cardRadius
        color: Theme.wellFill
        opacity: 0

        RevealSlide {
            target: search
            index: 0
            shown: root.shown
            fromRight: root.anchorRight
        }

        Inset {
            target: search
        }

        Text {
            id: searchGlyph

            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceSm + 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize
            color: Theme.overlay1
        }

        TextInput {
            id: field

            anchors.left: searchGlyph.right
            anchors.leftMargin: Theme.spaceSm
            anchors.right: count.left
            anchors.rightMargin: Theme.spaceXs
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.text
            selectionColor: Theme.blue
            selectedTextColor: Theme.crust
            selectByMouse: true
            clip: true

            Keys.onPressed: event => {
                if (root.cycleKey(event))
                    return;
                const ctrl = event.modifiers & Qt.ControlModifier;
                switch (event.key) {
                case Qt.Key_Escape:
                    root.closeRequested();
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (root.current)
                        root.activated(root.current);
                    break;
                case Qt.Key_Down:
                case Qt.Key_Tab:
                    root.step(1);
                    break;
                case Qt.Key_Up:
                case Qt.Key_Backtab:
                    root.step(-1);
                    break;
                case Qt.Key_PageDown:
                    root.step(8);
                    break;
                case Qt.Key_PageUp:
                    root.step(-8);
                    break;
                case Qt.Key_N:
                case Qt.Key_J:
                    if (!ctrl)
                        return;
                    root.step(1);
                    break;
                case Qt.Key_P:
                case Qt.Key_K:
                    if (!ctrl)
                        return;
                    root.step(-1);
                    break;
                case Qt.Key_Delete:
                    if (!(event.modifiers & Qt.ShiftModifier) || !root.current)
                        return;
                    root.removeRequested(root.current);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                font.pixelSize: 13
                color: Theme.surface2
                visible: field.text.length === 0
            }
        }

        Label {
            id: count

            anchors.right: trailingSlot.left
            anchors.rightMargin: trailingSlot.width > 0 ? Theme.spaceSm : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.results.length
            figures: true
            color: Theme.overlay0
        }

        Item {
            id: trailingSlot

            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceSm + 6
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Rectangle {
        id: well

        y: search.height + Theme.spaceXs
        width: parent.width
        height: parent.height - y - (hintLabel.visible ? hintLabel.height + Theme.spaceXs : 0) - root.footerRoom
        radius: Theme.cardRadius
        color: Theme.wellFill
        opacity: 0

        RevealSlide {
            target: well
            index: 1
            shown: root.shown
            fromRight: root.anchorRight
        }

        Inset {
            target: well
        }

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 5
            model: root.results
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false

            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            ScrollBar.vertical: ScrollBar {
                width: 5
                policy: ScrollBar.AsNeeded
            }
        }
    }

    Label {
        id: hintLabel

        anchors.horizontalCenter: parent.horizontalCenter
        y: well.y + well.height + Theme.spaceXs
        visible: root.hints !== ""
        text: root.hints
        color: Theme.surface2
        opacity: well.opacity
    }
}
