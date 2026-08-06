pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// The system meters in full, opened by hovering any of them: what each one is,
// what it currently reads, and the shape of the last couple of minutes.
//
// All of them at once rather than only the one under the pointer. They are read
// against each other more often than alone, and moving between them to compare
// meant losing the one just looked at.
//
// A chip each rather than one panel holding them all: they are separate
// readings, and the control centre's own cards set the pattern.
//
// Laid out as rows that narrow going up, so the block reads as a wedge with its
// wide end against the meters it describes. The widest row sits at the bottom
// beside the marks, and the taper falls away into empty screen rather than
// toward the rail. Chips take a few different widths within that, so the stack
// does not resolve into columns.
//
// One height for every chip, whatever it holds: a dial that stood taller would
// stretch the charts beside it to match, and a ring gains nothing from the
// height a chart wants.
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

    // One entry per meter: kind, icon, label, fill, the row it belongs to and
    // how wide it sits there.
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

    // room past the chips for the shadows they cast
    readonly property real shadowRoom: 16

    // One height for every chip, so a row is level whatever it holds and a
    // dial is a square puck rather than a tall block.
    readonly property real chipHeight: 118

    // The summary is four lines of text with the chip's own padding around
    // them, and nothing below to leave room for.
    readonly property real summaryHeight: 47 + Theme.spaceSm * 2

    // two 10px lines and the pixel between them, which is what a header's own
    // column comes to
    readonly property real headerHeight: 27

    // The widest row, which sits against the meters; the rest are narrower and
    // the stack tapers away from it.
    readonly property real baseWidth: 480

    implicitWidth: Theme.rail + Theme.spaceXs + baseWidth + shadowRoom
    exclusiveZone: 0

    // Purely a label: it never takes the pointer, which would otherwise steal
    // hover from the marks it is describing and flicker itself away.
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    // Holds the window mapped while the chips are still fading, since none of
    // them is the one thing whose opacity says whether anything is drawn.
    Timer {
        id: settling
        interval: Theme.morphDuration + Theme.staggerStep * 4
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
    // and on any entry slow enough to start the reveal twice, the whole stack
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

    // Grouped into rows by the row each meter names. Built as a list of lists
    // rather than filtered per row in the layout, so the number of rows follows
    // the model instead of being written into the structure.
    readonly property var rows: {
        const out = [];
        for (const m of meters) {
            const r = m.row ?? 0;
            while (out.length <= r)
                out.push([]);
            out[r].push(m);
        }
        // Rows are named from the bottom, where the wide end is, so a stack
        // laid out top down reads them in reverse.
        return out.reverse();
    }

    Column {
        id: stack

        // The wide end sits level with the meters and the taper runs upward, so
        // the block is placed by its foot rather than its middle.
        y: Math.round(Math.min(root.height - height - 10, Math.max(10, root.markY - height / 2)))

        // Spans the room beside the rail rather than hugging its contents: a
        // width taken from the children moves the stack as they slide, since on
        // the right hand screen its position is measured back from that width.
        x: root.anchorRight ? root.shadowRoom : Theme.rail + Theme.spaceXs
        width: root.width - Theme.rail - Theme.spaceXs - root.shadowRoom
        spacing: Theme.spaceXs

        Repeater {
            model: root.rows

            Row {
                id: chipRow

                required property var modelData
                required property int index

                // Counted from the bottom, so the row nearest the meters is
                // first in the reveal and the set builds upward away from them.
                readonly property int step: root.rows.length - 1 - index

                // Hugs its chips rather than spanning the stack, so a row is as
                // wide as what it holds and the taper is the shape of the rows
                // themselves. On the right hand rail the stack places each row
                // by its own right edge, which only works if that edge is the
                // last chip rather than the far side of the window.
                width: implicitWidth

                // Chips are one height, except the summary, which is a line of
                // text and has no chart to leave room for.
                readonly property bool summary: modelData.length > 0 && (modelData[0].kind ?? "") === "summary"

                height: summary ? root.summaryHeight : root.chipHeight
                spacing: Theme.spaceXs

                // Where the row settles once the slide is done. Handed to the
                // reveal rather than bound to x, which the slide writes to
                // directly and would break a binding on.
                readonly property real restX: root.anchorRight ? parent.width - width : 0

                // Rows hug the rail's own side, so the straight edge of the
                // wedge runs down beside it and the diagonal faces outward.
                layoutDirection: root.anchorRight ? Qt.RightToLeft : Qt.LeftToRight

                opacity: 0

                // The reveal rides the row rather than each chip: a Row places
                // its children's x itself, and a slide writing to a chip's own
                // x fights that and leaves them stacked at the origin. The row
                // is only positioned vertically by the column above it, so its
                // x is free for the slide to drive.
                //
                // It also means a row arrives as one thing rather than its
                // chips trickling in beside each other.
                RevealSlide {
                    target: chipRow
                    index: chipRow.step
                    shown: root.shown
                    fromRight: root.anchorRight
                    restX: chipRow.restX
                }

                Repeater {
                    model: chipRow.modelData

                    Rectangle {
                        id: chip

                        required property var modelData

                        // Width comes from the model, which is what shapes the
                        // wedge; height never varies.
                        implicitWidth: modelData.width
                        implicitHeight: chipRow.height

                        radius: 9
                        color: Theme.surfaceFill

                        // Resolved here rather than handed down with the rest: a
                        // model carrying live readings is rebuilt every sample,
                        // and the repeater over it would recreate this chip each
                        // time.
                        readonly property string kind: modelData.kind
                        readonly property bool isDial: modelData.dial ?? false

                        // ---- rates, for the chips that draw a chart ----

                        // Matched on the kind rather than falling through to a
                        // default: a kind with nothing to say here should draw
                        // nothing, not whatever the last branch happened to be.
                        readonly property var history: {
                            if (kind === "cpu")
                                return SysMeters.cpuHistory;
                            if (kind === "memory")
                                return SysMeters.memoryHistory;
                            if (kind === "gpu")
                                return SysMeters.gpuHistory;
                            if (kind === "io")
                                return SysMeters.diskReadHistory;
                            if (kind === "network")
                                return SysMeters.networkDownHistory;
                            return [];
                        }

                        // The two directional readings carry a second series;
                        // the rest leave it empty and draw one line.
                        readonly property var secondHistory: {
                            if (kind === "network")
                                return SysMeters.networkUpHistory;
                            if (kind === "io")
                                return SysMeters.diskWriteHistory;
                            return [];
                        }

                        readonly property bool hasSecond: secondHistory.length > 0

                        readonly property real ceiling: kind === "memory" ? SysMeters.memoryTotal : modelData.limit ?? Infinity

                        // The two rates a directional chip carries. Both kinds
                        // read the same way, so the only difference is where the
                        // numbers come from.
                        readonly property real firstRate: kind === "io" ? SysMeters.diskReadRate : SysMeters.networkDownRate
                        readonly property real secondRate: kind === "io" ? SysMeters.diskWriteRate : SysMeters.networkUpRate

                        // Both against one scale, so the pair is read as two
                        // parts of a figure rather than each in whatever unit
                        // happens to suit it.
                        readonly property int rateScale: SysMeters.byteScale(Math.max(firstRate, secondRate))

                        readonly property string detail: {
                            if (kind === "cpu")
                                return SysMeters.cpuTemperature > 0 ? SysMeters.cpu + "% · " + SysMeters.cpuTemperature + "°C" : SysMeters.cpu + "%";
                            if (kind === "memory")
                                return SysMeters.formatBytes(SysMeters.memoryUsed) + " / " + SysMeters.formatBytes(SysMeters.memoryTotal);
                            if (kind === "gpu")
                                return SysMeters.gpu + "% · " + SysMeters.gpuTemperature + "°C";
                            // What is left rather than what is taken: the ring
                            // already says what share is gone, and the figure
                            // worth reading beside it is the headroom.
                            if (isDial)
                                return SysMeters.formatBytes(total - used) + " free";
                            return "↓ " + SysMeters.formatBytesAt(firstRate, rateScale) + "/s";
                        }

                        readonly property string secondDetail: hasSecond ? "↑ " + SysMeters.formatBytesAt(secondRate, rateScale) + "/s" : ""

                        // The outgoing series, distinct from the chip's own
                        // colour but of a piece with it: sky against the
                        // network's teal, peach against the disk's yellow.
                        readonly property color secondFill: kind === "io" ? Theme.peach : Theme.sky

                        readonly property var format: {
                            if (kind === "cpu" || kind === "gpu")
                                return v => Math.round(v) + "%";
                            if (kind === "memory")
                                return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top));
                            return (v, top) => SysMeters.formatBytesAt(v, SysMeters.byteScale(top)) + "/s";
                        }

                        // ---- shares, for the chips that draw a ring ----

                        readonly property real used: kind === "vram" ? SysMeters.gpuMemoryUsed : SysMeters.diskUsed
                        readonly property real total: kind === "vram" ? SysMeters.gpuMemoryTotal : SysMeters.diskTotal
                        readonly property real fraction: total > 0 ? used / total : 0

                        // Its own blur, dropped at the halfway point of its own
                        // fade: a region is plain geometry and cannot fade with
                        // the chip, and the chip is translucent enough either
                        // side of halfway for the switch not to register.
                        //
                        // Summed through the row as well as the stack: a chip's
                        // own x is measured from its row, and a region is in
                        // window coordinates.
                        readonly property Region region: Region {
                            // The fade lives on the row now, so that is what
                            // says whether this chip is drawn.
                            readonly property bool active: chipRow.opacity > 0.5

                            x: stack.x + chipRow.x + chip.x
                            y: stack.y + chipRow.y + chip.y
                            width: active ? chip.width : 0
                            height: active ? chip.height : 0
                            radius: chip.radius
                        }

                        // A child of the chip, so the chip's own fade carries it
                        // in rather than it needing one of its own.
                        DropShadow {
                            target: chip
                            elevation: 6
                            strength: 0.35
                        }

                        Component.onCompleted: root.chipRegions.push(region)

                        Component.onDestruction: {
                            const i = root.chipRegions.indexOf(region);
                            if (i >= 0)
                                root.chipRegions.splice(i, 1);
                        }

                        // ---- who and what this machine is ----
                        //
                        // Not a reading, so it carries neither a chart nor a
                        // ring: user at host over the rest, in the same two
                        // line shape the other chips' headers use so it sits
                        // with them rather than on top of them.
                        Item {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceSm
                            visible: chip.kind === "summary"

                            // Sized against the block of text beside it rather
                            // than to the icon scale the headers use: it is the
                            // machine's mark rather than a label's bullet, and
                            // at header size it reads as a stray character next
                            // to four lines.
                            // Squared off against the block of text beside it,
                            // then inset: the mark sits in a box as tall as the
                            // text with its own breathing room inside that, so
                            // it reads as a logo with air around it rather than
                            // a glyph stretched to the full height.
                            //
                            // Asked for by pixel size, which is the em rather
                            // than the mark: this glyph paints 0.87 of that, so
                            // the size is scaled up to land on the height that
                            // is left once the inset is taken.
                            readonly property real logoInset: 7

                            // What the mark paints down the page, which is the
                            // text block less the inset above and below it. The
                            // size asked for is scaled off this rather than the
                            // other way round, so nothing here depends on the
                            // item's own geometry.
                            readonly property real logoHeight: summaryLines.implicitHeight - logoInset * 2
                            readonly property real logoSize: Math.round(logoHeight / 0.868)

                            Text {
                                id: summaryIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                text: chip.modelData.icon
                                font.family: Theme.iconFont
                                font.pixelSize: parent.logoSize
                                color: chip.modelData.fill

                                // The box is measured from what the mark
                                // actually paints, which is not square: this
                                // glyph covers a full em across but only 0.87
                                // of one down, and it overflows its own advance
                                // besides. Sized to the painted extents plus
                                // the inset on each side, the space around it
                                // comes out equal on all four.
                                width: parent.logoSize + parent.logoInset * 2
                                height: parent.logoHeight + parent.logoInset * 2
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            // One fact per line: the chip sits at the narrow end
                            // of the stack, and running them together would make
                            // it wider than the row beneath it.
                            Column {
                                id: summaryLines

                                anchors.left: summaryIcon.right
                                anchors.leftMargin: 26
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: SysMeters.userName + "@" + SysMeters.hostName
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: "up " + SysMeters.formatUptime(SysMeters.uptime)
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    font.features: {
                                        "tnum": 1
                                    }
                                    color: Theme.overlay1
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: SysMeters.osName
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    color: Theme.overlay1
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                // Named rather than bare: a version on its own
                                // is not obviously the kernel's, sitting under
                                // the distribution's own version.
                                Text {
                                    text: "Linux " + SysMeters.kernel
                                    font.family: Theme.font
                                    font.pixelSize: 10
                                    font.features: {
                                        "tnum": 1
                                    }
                                    color: Theme.overlay1
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }

                        // Every reading is a header over its content, whether
                        // that content is a chart or a ring: the two are read
                        // the same way down to the indent, and only what sits
                        // under the header differs.
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spaceSm
                            spacing: Theme.spaceXs
                            visible: chip.kind !== "summary"

                            Item {
                                width: parent.width

                                // Stated rather than measured off the text, so
                                // the chart below can be sized by subtracting
                                // it without the two disagreeing.
                                height: root.headerHeight

                                // Spans both rows rather than sitting on one,
                                // the way the connectivity tiles put their puck
                                // beside a name over a status line.
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

                                    // One reading, or two in the colours of the
                                    // lines they belong to: the chart is what
                                    // says which is which, so the figures carry
                                    // the same colours rather than a legend of
                                    // their own.
                                    Row {
                                        spacing: 6

                                        Text {
                                            text: chip.detail
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            font.features: {
                                                "tnum": 1
                                            }
                                            color: chip.hasSecond ? chip.modelData.fill : Theme.overlay1
                                        }

                                        Text {
                                            text: chip.secondDetail
                                            font.family: Theme.font
                                            font.pixelSize: 10
                                            font.features: {
                                                "tnum": 1
                                            }
                                            color: chip.secondFill
                                            visible: chip.hasSecond
                                        }
                                    }
                                }
                            }

                            // The reading itself, in whichever form suits it:
                            // a rate as a line over time, a share as a ring.
                            // Both take whatever the header left.
                            Sparkline {
                                width: parent.width

                                // Whatever the chip has left under its header.
                                // Measured from the chip rather than from this
                                // column's own height, which is derived from
                                // its children: a child sized against it is a
                                // loop the layout settles by leaving one of
                                // them at zero, and the line then draws outside
                                // the well it belongs in.
                                height: root.chipHeight - Theme.spaceSm * 2 - root.headerHeight - Theme.spaceXs
                                visible: !chip.isDial

                                values: chip.history
                                stroke: chip.modelData.fill
                                secondValues: chip.secondHistory
                                secondStroke: chip.secondFill
                                format: chip.format
                                limit: chip.ceiling
                            }

                            RadialGauge {
                                width: parent.width
                                height: root.chipHeight - Theme.spaceSm * 2 - root.headerHeight - Theme.spaceXs
                                visible: chip.isDial

                                level: chip.fraction
                                fill: chip.modelData.fill
                                label: Math.round(chip.fraction * 100) + "%"
                            }
                        }
                    }
                }
            }
        }
    }
}
