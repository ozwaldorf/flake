pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// The system meters in full, opened by hovering any of them: what each one is,
// what it currently reads, and the shape of the last couple of minutes.
//
// All three at once rather than only the one under the pointer. They are read
// against each other more often than alone, and moving between them to compare
// meant losing the one just looked at.
//
// A chip each rather than one panel holding all three: they are separate
// readings, and the control centre's own cards set the pattern. Each sizes to
// what it has to say instead of being held to a common width.
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

    property bool shown: false

    screen: screenData
    color: "transparent"
    visible: shown || settling.running

    anchors {
        left: !root.anchorRight
        right: root.anchorRight
        top: true
        bottom: true
    }

    // room for the rail, the gap the panel also uses, and the widest a chip is
    // likely to want
    implicitWidth: Theme.rail + Theme.spaceXs + 280
    exclusiveZone: 0

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the marks it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    // Holds the window mapped while the chips are still fading, since none of
    // them is the one thing whose opacity says whether anything is drawn.
    Timer {
        id: settling
        interval: Theme.morphDuration + Theme.staggerStep * 3
    }

    onShownChanged: {
        if (!shown)
            settling.restart();
    }

    // Populated by the chips, so the window blurs each rather than one box
    // covering the gaps between them.
    //
    // Starts with a rectangle of no size, which is never removed. A union with
    // nothing contributing to it falls back to covering the item it belongs
    // to, and here that is a window the height of the screen: every chip's
    // region is empty until it is halfway through its fade, so on the way in,
    // and on any entry slow enough to start the reveal twice, the whole column
    // blurs for those frames.
    property list<Region> chipRegions: [
        Region {
            width: 0
            height: 0
        }
    ]

    BackgroundEffect.blurRegion: Region {
        width: 0
        height: 0
        regions: root.chipRegions
    }

    Column {
        id: stack

        // Bottom up: the meters sit at the foot of the rail, so the chips grow
        // from there rather than from a point above them.
        y: Math.round(Math.min(root.height - height - 10, Math.max(10, root.markY - height / 2)))

        // Spans the room beside the rail rather than hugging its contents, and
        // the chips align themselves within it.
        //
        // A width taken from the children moves the stack as they slide, since
        // on the right hand screen its position is measured back from that
        // width: the travel cancels itself out and what is left reads as
        // arriving from the wrong side.
        x: root.anchorRight ? 0 : Theme.rail + Theme.spaceXs
        width: root.width - Theme.rail - Theme.spaceXs
        spacing: Theme.spaceXs

        Repeater {
            model: root.meters

            Rectangle {
                id: chip

                required property var modelData
                required property int index

                // sized to its own content rather than a shared width: a chip
                // says what it has to say and stops
                implicitWidth: body.implicitWidth + Theme.spaceSm * 2
                implicitHeight: body.implicitHeight + Theme.spaceSm * 2

                // Aligned to the rail's own side within the stack. Set as an
                // offset the slide adds to rather than an anchor, since the
                // reveal drives x directly and an anchor would fight it.
                readonly property real restX: root.anchorRight ? stack.width - width : 0

                radius: 9
                color: Theme.surfaceFill

                // Counted from the bottom, so the chip nearest the meters
                // arrives first and the set builds upward away from them.
                readonly property int step: root.meters.length - 1 - index

                // Resolved here rather than handed down with the rest: a model
                // carrying live readings is rebuilt every sample, and the
                // repeater over it would recreate this chip each time.
                readonly property string kind: modelData.kind

                readonly property var history: kind === "cpu" ? SysMeters.cpuHistory : kind === "memory" ? SysMeters.memoryHistory : SysMeters.networkHistory

                readonly property real ceiling: kind === "memory" ? SysMeters.memoryTotal : modelData.limit ?? Infinity

                readonly property string detail: {
                    if (kind === "cpu")
                        return SysMeters.cpu + "%";
                    if (kind === "memory")
                        return SysMeters.formatBytes(SysMeters.memoryUsed) + " / " + SysMeters.formatBytes(SysMeters.memoryTotal);
                    return SysMeters.formatBytes(SysMeters.networkRate) + "/s";
                }

                readonly property var format: {
                    if (kind === "cpu")
                        return v => Math.round(v) + "%";
                    if (kind === "memory")
                        return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top));
                    return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top)) + "/s";
                }

                opacity: 0

                RevealSlide {
                    target: chip
                    index: chip.step
                    shown: root.shown
                    fromRight: root.anchorRight
                    restX: chip.restX
                }

                // Its own blur, dropped at the halfway point of its own fade:
                // a region is plain geometry and cannot fade with the chip, and
                // the chip is translucent enough either side of halfway for the
                // switch not to register.
                readonly property Region region: Region {
                    readonly property bool active: chip.opacity > 0.5

                    x: stack.x + chip.x
                    y: stack.y + chip.y
                    width: active ? chip.width : 0
                    height: active ? chip.height : 0
                    radius: chip.radius
                }

                Component.onCompleted: root.chipRegions.push(region)

                Component.onDestruction: {
                    const i = root.chipRegions.indexOf(region);
                    if (i >= 0)
                        root.chipRegions.splice(i, 1);
                }

                Column {
                    id: body

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    Item {
                        // the header's own width, or the chart's if that is
                        // wider: the chip takes whichever its content needs
                        width: Math.max(icon.implicitWidth + Theme.spaceSm + lines.implicitWidth, graph.width)
                        implicitHeight: lines.implicitHeight

                        // Spans both rows rather than sitting on one, the way
                        // the connectivity tiles put their puck beside a name
                        // over a status line.
                        Text {
                            id: icon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: chip.modelData.icon
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.iconSize
                            color: chip.modelData.fill
                        }

                        Column {
                            id: lines

                            anchors.left: icon.right
                            anchors.leftMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: chip.modelData.label
                                font.family: Theme.font
                                font.pixelSize: 10
                                color: Theme.text
                            }

                            Text {
                                text: chip.detail
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

                        // its own natural width now that the chips are not
                        // held to a common size
                        width: implicitWidth
                        implicitHeight: 54
                        values: chip.history
                        stroke: chip.modelData.fill
                        format: chip.format
                        limit: chip.ceiling
                    }
                }
            }
        }
    }
}
