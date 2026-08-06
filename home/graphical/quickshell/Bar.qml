import QtQuick
import Quickshell
import Quickshell.Wayland
import "widgets"
import "services"

// Vertical rail anchored to the outward facing screen edge. Only the sliver is
// an exclusive zone, so tiled windows never reflow when the rail wakes; the
// rail draws over the desktop instead of pushing it.
PanelWindow {
    id: bar

    required property var modelData

    // anchor to the outward facing edge of the monitor arrangement, so the bar
    // sits on the far left of the leftmost screen and the far right of the
    // rightmost one rather than down the middle of a multi head setup
    required property bool anchorRight

    // held open while a modal is up, so moving toward one does not collapse it
    property bool modalOpen: false
    readonly property bool expanded: hover.hovered || modalOpen

    // sample the meters faster while this rail is out; released on destruction
    // so unplugging a monitor mid hover does not leave the count raised
    onExpandedChanged: SysMeters.watch(expanded)

    Component.onDestruction: {
        if (expanded)
            SysMeters.watch(false);
    }

    // name of the mark under the pointer, or empty
    signal markHovered(string name)

    property bool settingsActive: false

    screen: modelData
    color: "transparent"

    anchors {
        left: !bar.anchorRight
        right: bar.anchorRight
        top: true
        bottom: true
    }

    exclusiveZone: Theme.sliver

    // only the visible rail takes input; the rest of the fixed width surface
    // stays click through
    mask: Region {
        x: bar.railX
        y: 0
        width: bar.railWidth
        height: bar.height
    }

    // The surface stays at full rail width and the content animates inside it.
    // Animating implicitWidth means a right anchored surface is resized and
    // repositioned every frame, since its origin is derived from the width, and
    // those two commits are not atomic: the surface can present at the new size
    // before the new position lands, which shows as a gap at the screen edge.
    implicitWidth: Theme.rail

    // 0 collapsed, 1 expanded; drives everything that used to follow the width
    property real reveal: expanded ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    // visible width of the rail within the fixed surface
    readonly property real railWidth: Theme.sliver + (Theme.rail - Theme.sliver) * reveal

    // the rail hugs the outward edge, so the content is inset from the other side
    readonly property real railX: bar.anchorRight ? Theme.rail - railWidth : 0

    // Client side blur, following the visible rail rather than the surface,
    // which is now a fixed full width strip.
    BackgroundEffect.blurRegion: Region {
        x: bar.railX
        y: 0
        width: bar.railWidth
        height: bar.height
    }

    Rectangle {
        id: backdrop

        x: bar.railX
        y: 0
        width: bar.railWidth
        height: parent.height
        color: Theme.surfaceFill

        // hairline on the inward facing edge, whichever side that is
        Rectangle {
            anchors.right: bar.anchorRight ? undefined : parent.right
            anchors.left: bar.anchorRight ? parent.left : undefined
            width: 1
            height: parent.height
            color: Theme.surface0
            opacity: bar.expanded ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
    }

    // ---- tooltips ----
    //
    // The meters say how loaded things are but not what they are, and the rail
    // has no room to label them. Tracked here rather than in the marks so only
    // one is ever up, and so the tip can be given the mark's position in this
    // window's coordinates.

    // whichever mark the pointer is on, or null
    property var tipMark: null

    // Bound rather than copied, so the reading keeps counting while the tip is
    // up instead of freezing at whatever it was when the pointer arrived.
    readonly property string tipText: tipMark ? tipMark.label : ""

    property real tipY: 0

    function showTip(on, mark) {
        if (on) {
            tipMark = mark;
            // mapToItem rather than reading y directly: the mark is several
            // items deep, and its own y is relative to the column it sits in
            tipY = mark.mapToItem(bar.contentItem, 0, mark.height / 2).y;
        } else if (tipMark === mark) {
            // only the mark that raised it can lower it, or moving between two
            // adjacent meters would blank the tip the second one just set
            tipMark = null;
        }
    }

    // widened catch area so the pointer does not have to hit 6px exactly
    HoverHandler {
        id: rawHover
    }

    // debounce: quick to wake, slow to close
    property bool hovering: rawHover.hovered

    Timer {
        id: enterTimer
        interval: Theme.enterDelay
        onTriggered: hover.hovered = true
    }

    Timer {
        id: exitTimer
        interval: Theme.exitDelay
        onTriggered: hover.hovered = false
    }

    QtObject {
        id: hover
        property bool hovered: false
    }

    onHoveringChanged: {
        if (hovering) {
            exitTimer.stop();
            enterTimer.restart();
        } else {
            enterTimer.stop();
            exitTimer.restart();
        }
    }

    // Opening the control centre: the whole top corner of the rail, rather
    // than the mark alone. The mark is a small block in a narrow strip, and
    // aiming at it is the only fiddly part of reaching a panel that opens on
    // hover; the corner is what the pointer travels to anyway.
    //
    // Outside the padded content item so it reaches the rail's actual top
    // edge, and following the rail's width so it covers the sliver while
    // collapsed and the full width once out.
    Item {
        id: corner

        x: bar.railX
        y: 0
        width: bar.railWidth
        height: Theme.railPad + gear.height + Theme.railItemGap

        HoverHandler {
            id: cornerHover
            onHoveredChanged: bar.markHovered(hovered ? "settings" : "")
        }
    }

    // follows the rail, not the fixed surface, so the marks stay centred on the
    // visible strip as it widens
    Item {
        x: bar.railX
        y: Theme.railPad
        width: bar.railWidth
        height: parent.height - Theme.railPad * 2
        clip: true

        // actions: things you click
        Column {
            id: top

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.railGroupGap

            GearMark {
                id: gear

                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
                active: bar.settingsActive
                hovered: cornerHover.hovered
            }

            Workspaces {
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
            }
        }

        // status: things you read
        Column {
            id: bottom

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.railGroupGap

            // cpu, memory, network stacked down the rail, each as wide as a
            // workspace block so the two groups line up
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.meterGap

                LoadMeter {
                    id: cpuMeter

                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.cpu
                    fill: Theme.sapphire
                    label: "CPU " + SysMeters.cpu + "%"
                    onHoverChanged: hovered => bar.showTip(hovered, cpuMeter)
                }

                LoadMeter {
                    id: memMeter

                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.memory
                    fill: Theme.mauve
                    label: "Memory " + SysMeters.formatBytes(SysMeters.memoryUsed) + " / " + SysMeters.formatBytes(SysMeters.memoryTotal)
                    onHoverChanged: hovered => bar.showTip(hovered, memMeter)
                }

                LoadMeter {
                    id: netMeter

                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.network
                    fill: Theme.teal
                    // the rate itself rather than the percentage, which is of a
                    // fixed ceiling and not of the link's actual capacity
                    label: "Network " + SysMeters.formatBytes(SysMeters.networkRate) + "/s"
                    onHoverChanged: hovered => bar.showTip(hovered, netMeter)
                }
            }

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
            }
        }
    }

    // Only while the rail is out: in the sliver the meters are six pixels wide
    // and a label beside them would be most of what is on screen.
    RailTip {
        screenData: bar.modelData
        anchorRight: bar.anchorRight
        text: bar.tipText
        markY: bar.tipY
        shown: bar.tipMark !== null && bar.expanded
    }
}
