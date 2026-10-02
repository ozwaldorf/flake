pragma ComponentBehavior: Bound

import QtQuick
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
TipWindow {
    id: root

    // held mapped while the rows are still fading out, the last a few steps
    // behind the first
    settleTime: Theme.morphDuration + Theme.staggerStep * 4

    // One height for every chip, so a row is level whatever it holds and a
    // dial is a square puck rather than a tall block.
    readonly property real chipHeight: 118

    // The summary is four lines of text with the chip's own padding around
    // them, and nothing below to leave room for.
    readonly property real summaryHeight: 47 + Theme.spaceSm * 2

    // two 10px lines and the pixel between them, which is what a header's own
    // column comes to
    readonly property real headerHeight: 27

    // what a chart or a ring has left under the header
    readonly property real bodyHeight: chipHeight - Theme.spaceSm * 2 - headerHeight - Theme.spaceXs

    // The widest row, which sits against the meters; the rest are narrower and
    // the stack tapers away from it.
    readonly property real baseWidth: 480

    implicitWidth: Theme.rail + Theme.spaceXs + baseWidth + shadowRoom

    // Grouped into rows by the row each meter names. Built as a list of lists
    // rather than filtered per row in the layout, so the number of rows follows
    // the model instead of being written into the structure.
    readonly property var rows: {
        const out = [];
        for (const m of Meters.tip) {
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

        y: root.placeY(height)

        // Spans the room beside the rail rather than hugging its contents: a
        // width taken from the children moves the stack as they slide, since on
        // the right hand screen its position is measured back from that width.
        x: root.contentX
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
                readonly property bool summary: modelData.length > 0 && modelData[0].kind === "summary"

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

                        readonly property string kind: modelData.kind
                        readonly property var def: Meters.defs[kind]
                        readonly property bool isDial: def.dial ?? false
                        readonly property bool hasSecond: Meters.hasSecond(kind)

                        // Width comes from the layout, which is what shapes the
                        // wedge; height never varies.
                        implicitWidth: modelData.width
                        implicitHeight: chipRow.height

                        radius: Theme.cardRadius
                        color: Theme.surfaceFill

                        // switched at the halfway point of the row's fade, which
                        // the walk up to the window picks up
                        CardBlur {
                            target: chip
                            host: root
                        }

                        DropShadow {
                            target: chip
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
                            readonly property real logoHeight: summaryLines.implicitHeight - logoInset * 2
                            readonly property real logoSize: Math.round(logoHeight / 0.868)

                            Text {
                                id: summaryIcon

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                text: chip.def.icon
                                font.family: Theme.iconFont
                                font.pixelSize: parent.logoSize
                                color: chip.def.fill

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

                                Repeater {
                                    // Named rather than bare: a version on its
                                    // own is not obviously the kernel's, sitting
                                    // under the distribution's own version.
                                    model: [SysMeters.userName + "@" + SysMeters.hostName, "up " + SysMeters.formatUptime(SysMeters.uptime), SysMeters.osName, "Linux " + SysMeters.kernel]

                                    Label {
                                        required property string modelData
                                        required property int index

                                        width: parent.width
                                        text: modelData
                                        figures: index === 1 || index === 3
                                        color: index === 0 ? Theme.text : Theme.overlay1
                                        elide: Text.ElideRight
                                    }
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

                                    text: chip.def.icon
                                    font.family: Theme.iconFont
                                    font.pixelSize: Theme.iconSize
                                    color: chip.def.fill
                                }

                                Column {
                                    anchors.left: icon.right
                                    anchors.leftMargin: Theme.spaceSm
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Label {
                                        text: chip.def.label
                                    }

                                    // One reading, or two in the colours of the
                                    // lines they belong to: the chart is what
                                    // says which is which, so the figures carry
                                    // the same colours rather than a legend of
                                    // their own.
                                    Row {
                                        spacing: 6

                                        Label {
                                            text: Meters.detail(chip.kind)
                                            figures: true
                                            color: chip.hasSecond ? chip.def.fill : Theme.overlay1
                                        }

                                        Label {
                                            text: Meters.secondDetail(chip.kind)
                                            figures: true
                                            color: Meters.secondFill
                                            visible: chip.hasSecond
                                        }
                                    }
                                }
                            }

                            // The reading itself, in whichever form suits it:
                            // a rate as a line over time, a share as a ring.
                            //
                            // Sized from the chip rather than from this
                            // column's own height, which is derived from its
                            // children: a child sized against it is a loop the
                            // layout settles by leaving one of them at zero.
                            //
                            // Fed only while the window is up: hidden, the
                            // history would otherwise rebuild every chart on
                            // every sample for nobody.
                            Sparkline {
                                width: parent.width
                                height: root.bodyHeight
                                visible: !chip.isDial

                                values: root.visible ? Meters.history(chip.kind) : []
                                stroke: chip.def.fill
                                secondValues: root.visible ? Meters.secondHistory(chip.kind) : []
                                secondStroke: Meters.secondFill
                                format: Meters.format(chip.kind)
                                interval: SysMeters.historyInterval
                                limit: Meters.ceiling(chip.kind)
                            }

                            RadialGauge {
                                width: parent.width
                                height: root.bodyHeight
                                visible: chip.isDial

                                level: Meters.share(chip.kind)
                                fill: chip.def.fill
                                label: Math.round(Meters.share(chip.kind) * 100) + "%"
                            }
                        }
                    }
                }
            }
        }
    }
}
