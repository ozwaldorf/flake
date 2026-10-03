import QtQuick
import ".."

// A tile of the drawer's grid, cut into its surface: a small heading at the
// top, and whatever reading it holds below. Anything given as its backdrop is
// laid under the heading and the body, out to just inside the rim, so a chart
// can fill the tile rather than sit in a box within it.
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    property color tint: Theme.overlay1

    // a figure set against the heading, opposite it
    property string note: ""

    // space between the rim and what the tile holds
    property real padding: Theme.padCard

    // the same at the top alone, for a tile whose head wants it tighter
    property real paddingTop: padding

    default property alias content: body.data
    property alias backdrop: bleed.data

    radius: Theme.cardRadius
    color: Theme.wellFill

    Inset {
        target: root
    }

    // Short of the rim by a few pixels on every side: square corners against
    // the rounded ones would otherwise poke out past them.
    Item {
        id: bleed

        anchors.fill: parent
        anchors.margins: 5
    }

    Row {
        id: heading

        x: root.padding
        y: root.paddingTop - 2
        spacing: 6
        visible: root.title !== ""

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font.family: Theme.iconFont
            font.pixelSize: 11
            color: root.tint
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title.toUpperCase()
            font.pixelSize: 9
            font.letterSpacing: 1.2
            color: Theme.overlay1
        }
    }

    Label {
        anchors.right: parent.right
        anchors.rightMargin: root.padding
        anchors.verticalCenter: heading.verticalCenter
        text: root.note
        figures: true
        color: Theme.overlay0
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.title !== "" ? root.paddingTop + heading.height + Theme.spaceXs : root.paddingTop
    }
}
