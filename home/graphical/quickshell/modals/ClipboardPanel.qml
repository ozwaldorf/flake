pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../widgets"
import "../services"

// Clipboard history from cliphist: newest first, images as thumbnails, and
// the picked entry put back on the clipboard.
SearchPanel {
    id: root

    placeholder: "Search clipboard"
    glyph: Theme.iconClipboard
    hints: "enter copy    shift+del remove    esc close"
    results: live ? Clipboard.filter(query) : []

    onShownChanged: {
        if (shown)
            Clipboard.refresh();
    }

    onActivated: result => {
        Clipboard.copy(result);
        root.closeRequested();
    }

    onRemoveRequested: result => Clipboard.remove(result)

    delegate: ResultRow {
        id: row

        required property var modelData
        required property int index

        readonly property string thumb: Clipboard.thumb(modelData)

        current: ListView.isCurrentItem
        glyph: modelData.image ? Theme.iconImage : Theme.iconText
        title: modelData.image ? "Image" : modelData.text.replace(/\s+/g, " ").trim()
        detail: modelData.image ? modelData.text : ""
        hint: "copy"
        implicitHeight: modelData.image ? 64 : 36
        leadSize: modelData.image ? 48 : 28

        leading: Image {
            anchors.fill: parent
            visible: row.thumb !== "" && status === Image.Ready
            source: row.thumb
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        onEntered: root.select(index)
        onTapped: root.activated(modelData)
    }

    // Clearing the whole history, at the end of the field, and only while
    // there is something to clear.
    trailing: Text {
        id: clearAll

        readonly property bool has: Clipboard.entries.length > 0

        visible: has
        text: Theme.iconTrash
        font.family: Theme.iconFont
        font.pixelSize: 13
        color: clearHover.hovered ? Theme.red : Theme.overlay0

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }

        HoverHandler {
            id: clearHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: Clipboard.wipe()
        }
    }
}
