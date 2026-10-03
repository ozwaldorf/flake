pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../widgets"
import "../services"

// The compositor's keybinds, grouped, each with its keys set out as caps
// against the far edge. Read only: typing narrows the list.
SearchPanel {
    id: root

    placeholder: "Search shortcuts"
    glyph: Theme.iconKeyboard
    hints: "esc close"
    results: Keybinds.filter(query)

    delegate: Column {
        id: entry

        required property var modelData
        required property int index

        readonly property bool leads: index === 0 || root.results[index - 1]?.group !== modelData.group

        width: ListView.view.width

        Label {
            visible: entry.leads
            height: visible ? implicitHeight + Theme.spaceSm : 0
            leftPadding: Theme.spaceXs
            topPadding: entry.index === 0 ? 4 : Theme.spaceSm
            verticalAlignment: Text.AlignBottom
            text: entry.modelData.group.toUpperCase()
            font.pixelSize: 9
            font.letterSpacing: 1.2
            color: Theme.overlay1
        }

        Rectangle {
            width: parent.width
            height: 30
            radius: 6
            color: entry.ListView.isCurrentItem ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        root.select(entry.index);
                }
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceXs
                anchors.right: caps.left
                anchors.rightMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.label
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Row {
                id: caps

                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: entry.modelData.key.split("+")

                    Rectangle {
                        id: cap

                        required property string modelData

                        width: Math.max(height, capLabel.implicitWidth + 10)
                        height: 18
                        radius: 4
                        color: Theme.surface1

                        Label {
                            id: capLabel

                            anchors.centerIn: parent
                            text: cap.modelData === "Mod" ? "Super" : cap.modelData
                            color: Theme.subtext1
                        }
                    }
                }
            }
        }
    }
}
