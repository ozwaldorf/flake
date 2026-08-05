pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One audio level as a card: a label row carrying the device name and a
// chevron, the level under it as a glyph beside a thin track, and the device
// picker expanding inside the same card. Tapping the glyph mutes.
Rectangle {
    id: root

    // what the glyph draws and which half of Pipewire this drives:
    // "speaker" for the default sink, "mic" for the default source
    required property string device

    required property string label

    property real value: 0
    property bool muted: false

    property bool expanded: false

    signal moved(real value)
    signal muteToggled

    // exposed so the panel can tell the pointer is still inside it
    signal hoverChanged(bool hovered)

    readonly property bool isSink: device === "speaker"
    readonly property real clamped: Math.max(0, Math.min(1, value))

    readonly property var devices: isSink ? Audio.sinks : Audio.sources
    readonly property var current: isSink ? Audio.sink : Audio.source

    implicitHeight: body.implicitHeight + Theme.spaceSm * 2
    radius: 9
    color: Qt.alpha(Theme.surface0, 0.5)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        // ---- label row ----

        Item {
            width: parent.width
            implicitHeight: 16

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.text
            }

            // Current device, sharing the row with the label so the card says
            // what it is driving without being opened.
            Text {
                anchors.right: chevron.left
                anchors.rightMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - 90)
                horizontalAlignment: Text.AlignRight
                text: Audio.label(root.current)
                font.family: Theme.font
                font.pixelSize: 10
                color: pickHover.hovered ? Theme.subtext0 : Theme.overlay0
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }
            }

            // rotates to point down when the picker is out
            Chevron {
                id: chevron

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                open: root.expanded
                fill: pickHover.hovered ? Theme.text : Theme.overlay0
            }

            // The whole row opens the picker, not just the chevron: a 12px
            // target is not worth aiming at when the row is already there.
            HoverHandler {
                id: pickHover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.hoverChanged(hovered)
            }

            TapHandler {
                onTapped: root.expanded = !root.expanded
            }
        }

        // ---- level ----

        // Glyph outside the track rather than inset in it, with the track
        // taking whatever width is left. The hit area is the whole row so the
        // 4px track is not what you have to aim at.
        Item {
            width: parent.width
            implicitHeight: 20

            Item {
                id: glyphSlot

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 14

                readonly property color tint: root.muted ? Theme.surface2 : Theme.overlay2

                SpeakerGlyph {
                    anchors.centerIn: parent
                    visible: root.isSink
                    muted: root.muted
                    fill: glyphSlot.tint
                    // arcs follow the level, so a quiet sink reads as quiet
                    // before you look at the track
                    arcs: root.clamped > 0.5 ? 2 : root.clamped > 0 ? 1 : 0
                }

                MicGlyph {
                    anchors.centerIn: parent
                    visible: !root.isSink
                    muted: root.muted
                    fill: glyphSlot.tint
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.hoverChanged(hovered)
                }

                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: root.muteToggled()
                }
            }

            // Taller than the track so the hit target is not a 4px sliver.
            Item {
                id: hit

                anchors.left: glyphSlot.right
                anchors.leftMargin: Theme.spaceSm
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height

                Rectangle {
                    id: track

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: Theme.barThickness
                    radius: height / 2
                    color: Qt.alpha(Theme.surface2, 0.55)

                    Rectangle {
                        width: Math.max(0, parent.width * root.clamped)
                        height: parent.height
                        radius: parent.radius
                        color: root.muted ? Theme.surface2 : Theme.subtext0

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        Behavior on width {
                            enabled: !drag.active
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                }

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onCentroidChanged: {
                        if (active)
                            root.moved(Math.max(0, Math.min(1, centroid.position.x / track.width)));
                    }
                }

                TapHandler {
                    onTapped: eventPoint => root.moved(Math.max(0, Math.min(1, eventPoint.position.x / track.width)))
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: root.hoverChanged(hovered)
                }
            }
        }

        // ---- device picker ----

        Item {
            width: parent.width
            clip: true

            implicitHeight: root.expanded ? Math.min(picker.implicitHeight, 150) : 0
            opacity: root.expanded ? 1 : 0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.morphDuration
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }

            Flickable {
                anchors.fill: parent
                contentHeight: picker.implicitHeight
                contentWidth: width
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: picker

                    width: parent.width
                    spacing: 1
                    topPadding: Theme.spaceXs

                    Repeater {
                        model: root.devices

                        Rectangle {
                            id: entry

                            required property var modelData

                            readonly property bool active: Audio.isDefault(modelData, root.isSink)

                            width: picker.width
                            implicitHeight: 26
                            radius: 6
                            color: entryHover.hovered ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }

                            // filled dot on the device currently in use
                            Rectangle {
                                id: marker

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 5
                                implicitHeight: 5
                                radius: 2.5
                                color: entry.active ? Theme.blue : Qt.alpha(Theme.blue, 0)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 160
                                    }
                                }
                            }

                            Text {
                                anchors.left: marker.right
                                anchors.leftMargin: Theme.spaceSm
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spaceSm
                                anchors.verticalCenter: parent.verticalCenter
                                text: Audio.label(entry.modelData)
                                font.family: Theme.font
                                font.pixelSize: 10
                                color: entry.active ? Theme.text : Theme.subtext0
                                elide: Text.ElideRight
                            }

                            HoverHandler {
                                id: entryHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: root.hoverChanged(hovered)
                            }

                            TapHandler {
                                onTapped: {
                                    if (root.isSink)
                                        Audio.setSink(entry.modelData);
                                    else
                                        Audio.setSource(entry.modelData);
                                    root.expanded = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
