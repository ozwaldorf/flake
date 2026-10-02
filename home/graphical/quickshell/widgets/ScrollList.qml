import QtQuick
import ".."

// Rows in a disclosed list, scrolling once there are more than the container
// lets it show.
Flickable {
    id: root

    default property alias rows: list.data

    // shown in place of the rows while there are none yet
    property string placeholder: ""
    property bool empty: false

    // what the list wants to be, for the container that caps and animates it
    readonly property real wantedHeight: list.implicitHeight

    contentHeight: list.implicitHeight
    contentWidth: width
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Column {
        id: list

        width: parent.width
        spacing: 1

        Label {
            width: parent.width
            height: visible ? 30 : 0
            visible: root.placeholder !== "" && root.empty
            verticalAlignment: Text.AlignVCenter
            leftPadding: Theme.spaceSm
            text: root.placeholder
            color: Theme.surface2
        }
    }
}
