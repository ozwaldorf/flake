pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "widgets"
import "services"

// The windows open on one screen, along its foot. Sits behind the desktop as
// the rail does, in a strip held clear of it, and runs from the rail to the
// far edge, giving way as the rail and its drawers push the desktop aside.
Scope {
    id: root

    required property var modelData
    required property bool anchorRight

    // how far the rail has pushed the desktop off its edge
    property real push: 0

    // how deep the recess is cut, matched to the rail's
    property real recess: 0.3

    // Holds the windows clear of the strip. Apart from the strip itself, which
    // ignores the rail's zone so it does not jump across when that changes:
    // it follows the rail's own spring instead.
    PanelWindow {
        screen: root.modelData
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-taskbar-zone"
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: Theme.taskBar
        implicitHeight: 1

        anchors {
            left: true
            right: true
            bottom: true
        }
    }

    PanelWindow {
        id: strip

        screen: root.modelData
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-taskbar"
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: Theme.taskBar

        anchors {
            left: true
            right: true
            bottom: true
        }

        // as the rail's, explicitly empty so a reused surface does not keep
        // blurring under the strip
        BackgroundEffect.blurRegion: Region {}

        // past the rail, which shows through the rest
        mask: Region {
            item: ground
        }

        Rectangle {
            id: ground

            x: root.anchorRight ? 0 : Math.min(root.push, strip.width)
            width: Math.max(0, strip.width - root.push)
            height: strip.height
            color: Theme.base
            clip: true

            // the desktop casting down onto the strip, and the screen's own
            // edges cast the same, as along the rail
            EdgeShadow {
                side: "top"
                peak: root.recess
            }

            EdgeShadow {
                y: parent.height - height
                side: "bottom"
                peak: root.recess
            }

            EdgeShadow {
                x: root.anchorRight ? 0 : parent.width - width
                side: root.anchorRight ? "left" : "right"
                peak: root.recess
            }

            Row {
                id: entries

                // shrunk to share the strip once they no longer fit at full width
                readonly property int count: Niri.windowCounts[root.modelData.name] ?? 0
                readonly property real fit: (ground.width - Theme.spaceXs * 2 - Theme.taskGap * Math.max(0, count - 1)) / Math.max(1, count)
                readonly property real entryWidth: Math.max(Theme.taskEntryHeight, Math.min(Theme.taskEntryWidth, fit))

                x: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.taskGap

                Repeater {
                    // the live model with other screens' windows hidden, as for
                    // the workspace marks
                    model: Niri.windows

                    Item {
                        id: slot

                        required property int winId
                        required property string output
                        required property string title
                        required property string appId
                        required property bool urgent
                        required property bool active
                        required property bool shown
                        required property bool lead

                        // the Row skips hidden children, so this takes no slot
                        visible: output === root.modelData.name

                        // a wider gap where one workspace's windows give way to the next
                        readonly property real gap: lead ? Theme.spaceSm - Theme.taskGap : 0

                        width: gap + entry.width
                        height: Theme.taskEntryHeight

                        Rectangle {
                            id: entry

                            readonly property var desktop: DesktopEntries.heuristicLookup(slot.appId)
                            readonly property string icon: desktop?.icon ?? ""
                            readonly property string iconSource: icon.startsWith("/") ? `file://${icon}` : icon !== "" ? Quickshell.iconPath(icon, true) : ""

                            x: slot.gap
                            // as wide as its title, up to the share the strip allows
                            width: Math.min(entries.entryWidth, iconSlot.anchors.leftMargin + iconSlot.width + titleLabel.implicitWidth + Theme.spaceXs * 2)
                            height: parent.height
                            radius: Theme.cardRadius - 3

                            // alpha zero rather than "transparent", so the fade
                            // does not pass through black
                            color: slot.active ? Theme.surface0 : hover.hovered ? Qt.alpha(Theme.surface0, 0.5) : Qt.alpha(Theme.surface0, 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.hoverDuration
                                }
                            }

                            Item {
                                id: iconSlot

                                anchors.left: parent.left
                                anchors.leftMargin: (Theme.taskEntryHeight - width) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.taskIconSize
                                height: Theme.taskIconSize
                                opacity: slot.shown ? 1 : 0.6

                                Image {
                                    readonly property int px: Math.ceil(width * Screen.devicePixelRatio)

                                    anchors.fill: parent
                                    visible: entry.iconSource !== ""
                                    source: entry.iconSource
                                    sourceSize.width: px
                                    sourceSize.height: px
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: entry.iconSource === ""
                                    text: Theme.iconApp
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: Theme.overlay1
                                }
                            }

                            Label {
                                id: titleLabel

                                anchors.left: iconSlot.right
                                anchors.leftMargin: Theme.spaceXs
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spaceXs
                                anchors.verticalCenter: parent.verticalCenter
                                visible: width > 0
                                text: slot.title !== "" ? slot.title : (entry.desktop?.name ?? slot.appId)
                                font.pixelSize: 11
                                color: slot.active ? Theme.text : slot.shown ? Theme.subtext0 : Theme.overlay0
                                elide: Text.ElideRight
                                maximumLineCount: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.hoverDuration
                                    }
                                }
                            }

                            // the focus light, in the workspace marks' blue, or
                            // red while the window asks for attention
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: parent.width - parent.radius * 2
                                height: 2
                                color: slot.urgent ? Theme.red : Theme.blue
                                opacity: slot.urgent || slot.active ? 1 : 0

                                Behavior on opacity {
                                    Fade {}
                                }
                            }

                            HoverHandler {
                                id: hover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: Niri.focusWindow(slot.winId)
                            }
                        }
                    }
                }
            }
        }
    }
}
