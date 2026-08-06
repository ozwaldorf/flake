pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// The system meters in full, opened by hovering any of them: what each one is,
// what it currently reads, and the shape of the last couple of minutes.
//
// All three at once rather than only the one under the pointer. They are read
// against each other more often than alone, and moving between them to compare
// meant losing the one just looked at.
//
// Its own layer surface rather than an item in the bar: the bar's window is
// only as wide as the rail and masked to it, so anything drawn outside would
// be clipped. Matches the tray menu, which is a layer surface for the same
// reason.
PanelWindow {
    id: root

    required property var screenData

    // which edge the rail is on, so the tip opens inward
    required property bool anchorRight

    // one entry per meter: icon, label, detail, history, fill
    property var meters: []

    // vertical centre of the group this is labelling, in window coordinates
    property real markY: 0

    // Widest axis any of the charts needs, which they all then reserve so
    // their plots line up. A percentage is half the width of a byte rate, so
    // left to themselves the three would each end somewhere different.
    //
    // Raised rather than recomputed: the delegates are not addressable from
    // here, and a unit only ever grows the gutter as the readings move. It is
    // reset when the tip closes so a spell of heavy traffic does not leave the
    // axis padded for it forever.
    property real gutter: 0

    onShownChanged: {
        if (!shown)
            gutter = 0;
    }

    property bool shown: false

    screen: screenData
    color: "transparent"
    visible: shown || fade.running

    anchors {
        left: !root.anchorRight
        right: root.anchorRight
        top: true
        bottom: true
    }

    // room for the rail, the gap the panel also uses, and the tip itself
    implicitWidth: Theme.rail + 8 + 240
    exclusiveZone: 0

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the marks it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: tip

        // just past the rail, on whichever side it is anchored to
        x: root.anchorRight ? root.width - Theme.rail - 8 - width : Theme.rail + 8

        // Centred on the group, then held clear of the screen edges: the meters
        // sit low on the rail and a tall tip would otherwise run off the bottom.
        y: Math.round(Math.max(10, Math.min(root.height - height - 10, root.markY - height / 2)))

        implicitWidth: body.implicitWidth + Theme.spaceSm * 2
        implicitHeight: body.implicitHeight + Theme.spaceSm * 2

        // The panel's own fill and nothing more: this is a surface in its own
        // right rather than a card sitting on one, so the wash the cards add
        // belongs on the charts inside it instead.
        radius: 9
        color: Theme.surfaceFill

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                id: fade
                duration: Theme.fadeDuration
            }
        }

        Column {
            id: body

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.spaceSm
            spacing: Theme.spaceSm

            Repeater {
                model: root.meters

                Column {
                    id: entry

                    required property var modelData

                    spacing: Theme.spaceXs

                    Item {
                        width: graph.width
                        implicitHeight: lines.implicitHeight

                        // Spans both rows rather than sitting on one, the way
                        // the connectivity tiles put their puck beside a name
                        // over a status line.
                        Text {
                            id: icon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: entry.modelData.icon
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: entry.modelData.fill
                        }

                        Column {
                            id: lines

                            anchors.left: icon.right
                            anchors.leftMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: entry.modelData.label
                                font.family: Theme.font
                                font.pixelSize: 10
                                color: Theme.text
                            }

                            Text {
                                text: entry.modelData.detail
                                font.family: Theme.font
                                font.pixelSize: 10
                                font.features: {
                                    "tnum": 1
                                }
                                color: Theme.overlay1
                            }
                        }
                    }

                    Sparkline {
                        id: graph

                        width: 200
                        implicitHeight: 54
                        values: entry.modelData.history
                        stroke: entry.modelData.fill
                        format: entry.modelData.format
                        limit: entry.modelData.limit ?? Infinity

                        gutter: root.gutter
                        onAxisWidthChanged: root.gutter = Math.max(root.gutter, axisWidth)
                        Component.onCompleted: root.gutter = Math.max(root.gutter, axisWidth)
                    }
                }
            }
        }
    }

    // blur behind it like every other surface, dropped at the halfway point of
    // the fade so it does not linger as a ghost
    BackgroundEffect.blurRegion: Region {
        readonly property bool active: tip.opacity > 0.5

        x: tip.x
        y: tip.y
        width: active ? tip.width : 0
        height: active ? tip.height : 0
        radius: tip.radius
    }
}
