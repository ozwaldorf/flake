pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../widgets"

// Every drawer the rail holds, as a row of tabs at the foot of whichever is
// open. A window of its own rather than part of each page, so it holds still
// while the pages slide past above it, with the light on the one in view
// travelling along to meet it.
EdgeWindow {
    id: root

    property bool shown: false

    // how far the desktop has slid off the screen edge, as for the pages
    property real revealWidth: width

    // the pages in their order, and the one in view
    property var pages: []
    property string current: ""

    readonly property var tabs: ({
            settings: {
                label: "Control",
                glyph: String.fromCodePoint(0xf013)
            },
            info: {
                label: "System",
                glyph: Theme.iconCpu
            },
            apps: {
                label: "Apps",
                glyph: Theme.iconApp
            },
            clipboard: {
                label: "Clipboard",
                glyph: Theme.iconClipboard
            },
            keys: {
                label: "Keys",
                glyph: Theme.iconKeyboard
            }
        })

    signal picked(string name)
    signal hoverChanged(bool hovered)

    WlrLayershell.namespace: "quickshell-tabs"

    implicitWidth: Theme.rail + Theme.railInset + Theme.drawerWidth + shadowRoom

    // Mapped for good and switched by its region, as the pages are.
    mask: Region {
        x: row.x
        y: row.y
        width: root.shown ? row.width : 0
        height: root.shown ? row.height : 0
    }

    BackgroundEffect.blurRegion: Region {
        width: 0
        height: 0
    }

    // uncovered by the desktop sliding off it, like the pages above
    Item {
        id: clipper

        x: root.anchorRight ? root.width - Math.min(root.revealWidth, root.width) : Theme.rail
        width: Math.max(0, Math.min(root.revealWidth, root.width) - Theme.rail)
        height: root.height
        clip: true

        Item {
            x: -clipper.x
            width: root.width
            height: root.height

            Rectangle {
                id: row

                readonly property real segment: width / Math.max(1, root.pages.length)
                readonly property int index: root.pages.indexOf(root.current)

                // Held while no drawer is open, so the light slides over from
                // the last one rather than in from the end of the row.
                property int lastIndex: 0
                onIndexChanged: {
                    if (index >= 0)
                        lastIndex = index;
                }

                x: root.anchorRight ? root.shadowRoom : Theme.rail + Theme.railInset
                y: root.height - Theme.railPad - height
                width: Theme.drawerWidth
                height: Theme.tabsHeight
                radius: Theme.cardRadius
                color: Theme.wellFill
                opacity: root.shown ? 1 : 0

                Behavior on opacity {
                    Fade {}
                }

                Inset {
                    target: row
                }

                Rectangle {
                    x: row.lastIndex * row.segment + 4
                    y: 4
                    width: row.segment - 8
                    height: row.height - 8
                    radius: Theme.cardRadius - 3
                    color: Theme.surface0

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.morphDuration
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: root.pages

                        Item {
                            id: tab

                            required property string modelData

                            readonly property bool active: root.current === modelData
                            readonly property color tint: active ? Theme.text : hover.hovered ? Theme.subtext0 : Theme.overlay0

                            width: row.segment
                            height: row.height

                            Column {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.tabs[tab.modelData]?.glyph ?? ""
                                    font.family: Theme.iconFont
                                    font.pixelSize: 13
                                    color: tab.tint

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.hoverDuration
                                        }
                                    }
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.tabs[tab.modelData]?.label ?? tab.modelData
                                    font.pixelSize: 9
                                    color: tab.tint

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.hoverDuration
                                        }
                                    }
                                }
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: root.picked(tab.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    HoverHandler {
        onHoveredChanged: root.hoverChanged(hovered)
    }
}
