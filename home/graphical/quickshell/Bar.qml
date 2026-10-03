pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "widgets"
import "services"

// Vertical rail anchored to the outward facing screen edge. It sits behind the
// desktop rather than over it: waking the rail widens the exclusive zone so the
// windows move aside, the wallpaper slides with them, and the rail is revealed
// in the gap they leave.
EdgeWindow {
    id: bar

    // held open while the panel is up, so moving toward it does not collapse
    // the rail
    property bool panelOpen: false
    readonly property bool expanded: railHovered || panelOpen

    // whether the pointer is on the corner zone that opens the panel
    readonly property bool cornerHovered: cornerHover.hovered

    // sample the meters faster while this rail is out; released on destruction
    // so unplugging a monitor mid hover does not leave the count raised
    onExpandedChanged: {
        SysMeters.watch(expanded);
        spring.retarget();
    }

    Component.onDestruction: {
        if (expanded)
            SysMeters.watch(false);
    }

    // Top rather than under the windows: niri zooms the background and bottom
    // layers out with the workspaces in the overview, and the rail has to stay
    // pinned to the screen edge. The windows slide in step with the rail
    // anyway, so they barely overlap it on the way back.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"

    // Switched outright rather than following the reveal: every change is a
    // relayout of the whole output, and the compositor animates the windows
    // across on its own.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: expanded ? Theme.rail : Theme.sliver

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
    shadowRoom: 0

    implicitWidth: Theme.rail

    // 0 collapsed, 1 expanded; every width on the rail, and the toasts beside
    // it, follow this one value
    property real reveal: 0

    // The windows are moved by niri's horizontal view spring when the zone
    // changes, so the rail runs the same one: critically damped, stiffness
    // 800, unit mass, carrying its velocity into a reversal the way niri
    // does. Solved in closed form from the moment of each retarget rather
    // than integrated, so frame pacing does not drift it off niri's curve.
    FrameAnimation {
        id: spring

        readonly property real omega: Math.sqrt(800) / Theme.motionScale
        property real target: 0
        property real c1: 0
        property real c2: 0
        property real startedAt: 0
        property real velocity: 0

        function retarget() {
            target = bar.expanded ? 1 : 0;
            c1 = bar.reveal - target;
            c2 = velocity + omega * c1;
            startedAt = Date.now();
            restart();
        }

        onTriggered: {
            // wall clock rather than summed frame times: the first frame after a
            // restart reports the whole idle gap as its frame time
            const t = (Date.now() - startedAt) / 1000;
            const decay = Math.exp(-omega * t);
            const offset = (c1 + c2 * t) * decay;
            velocity = (c2 - omega * (c1 + c2 * t)) * decay;
            if (Math.abs(offset) < 0.0001 && Math.abs(velocity) < 0.01) {
                velocity = 0;
                bar.reveal = target;
                stop();
                return;
            }
            bar.reveal = target + offset;
        }
    }

    // visible width of the rail within the fixed surface
    readonly property real railWidth: Theme.sliver + (Theme.rail - Theme.sliver) * reveal

    // The rail hugs the outward edge, so the content is inset from the other
    // side, measured from the window's own edge.
    readonly property real railX: bar.anchorRight ? width - railWidth : 0

    // Explicitly empty rather than unset: a surface kept across a reload holds
    // on to whatever region it was last given, and the transparent part of the
    // strip would go on blurring the wallpaper sliding under it.
    BackgroundEffect.blurRegion: Region {}

    // Opaque: the rail is what lies behind the wallpaper, so there is nothing
    // further back to show through it.
    Rectangle {
        id: backdrop

        x: bar.railX
        y: 0
        width: bar.railWidth
        height: parent.height
        color: Theme.mantle
        clip: true

        // Cast by the desktop onto the rail, along the inward edge where the
        // wallpaper overlaps it. Deepens as the rail opens, so the desktop
        // reads as lifting away rather than only sliding.
        Rectangle {
            id: deskShadow

            readonly property real peak: 0.35 + 0.2 * bar.reveal

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: bar.anchorRight ? undefined : parent.right
            anchors.left: bar.anchorRight ? parent.left : undefined
            width: 18

            // Falls away quickly rather than evenly across its width: a linear
            // ramp is still visibly dark where it ends, which reads as a band
            // with an edge rather than a shadow fading out.
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Qt.alpha("black", bar.anchorRight ? deskShadow.peak : 0)
                }
                GradientStop {
                    position: bar.anchorRight ? 0.35 : 0.65
                    color: Qt.alpha("black", deskShadow.peak * 0.22)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("black", bar.anchorRight ? 0 : deskShadow.peak)
                }
            }
        }
    }

    // Centre of the meter group, so the tip opens level with what it describes.
    // Summed from the items' own geometry rather than mapped: a mapToItem call
    // does not re-evaluate when they move.
    readonly property real tipY: railContent.y + bottom.y + meters.y + meters.height / 2

    // Centre of the clock, summed the same way, so the calendar opens level
    // with the digits it belongs to.
    readonly property real clockY: railContent.y + bottom.y + clock.y + clock.height / 2

    // widened catch area so the pointer does not have to hit 6px exactly
    HoverHandler {
        id: rawHover
    }

    // Debounced: quick to wake, slow to close.
    property bool railHovered: false

    Timer {
        id: enterTimer
        interval: Theme.enterDelay
        onTriggered: bar.railHovered = true
    }

    Timer {
        id: exitTimer
        interval: Theme.exitDelay
        onTriggered: bar.railHovered = false
    }

    Connections {
        target: rawHover

        function onHoveredChanged() {
            if (rawHover.hovered) {
                exitTimer.stop();
                enterTimer.restart();
            } else {
                enterTimer.stop();
                exitTimer.restart();
            }
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
        x: bar.railX
        y: 0
        width: bar.railWidth
        height: Theme.railPad + gear.height + Theme.railItemGap

        HoverHandler {
            id: cornerHover
        }
    }

    // follows the rail, not the fixed surface, so the marks stay centred on the
    // visible strip as it widens
    Item {
        id: railContent

        x: bar.railX
        y: Theme.railPad
        width: bar.railWidth
        height: parent.height - Theme.railPad * 2
        clip: true

        // actions: things you click
        Column {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.railGroupGap

            GearMark {
                id: gear

                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
                reveal: bar.reveal
                active: bar.panelOpen
                hovered: cornerHover.hovered
            }

            Workspaces {
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
                reveal: bar.reveal
                screenData: bar.modelData
            }
        }

        // status: things you read
        Column {
            id: bottom

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.railGroupGap

            // stacked down the rail, each as wide as a workspace block so the
            // two groups line up
            Column {
                id: meters

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.meterGap

                Repeater {
                    model: Meters.rail

                    LoadMeter {
                        required property string modelData

                        anchors.horizontalCenter: parent.horizontalCenter
                        reveal: bar.reveal
                        value: Meters.level(modelData)
                        fill: Meters.defs[modelData].fill
                        secondValue: Meters.secondLevel(modelData)
                        secondFill: Meters.hasSecond(modelData) ? Meters.secondFill : "transparent"
                    }
                }
            }

            Clock {
                id: clock

                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
            }
        }

        // One target over the whole meter group rather than one per meter: the
        // tip shows them all, so which one the pointer is on does not matter,
        // and travelling between them never drops it. Spans the rail so the
        // marks are not what has to be hit.
        //
        // Placed by summing the group's offsets rather than by mapToItem,
        // which is a one shot call with no dependency tracking. A Column
        // refuses vertical anchors on its children besides, so this sits
        // outside the columns entirely.
        Item {
            x: (railContent.width - width) / 2
            y: bottom.y + meters.y
            width: Theme.rail
            height: meters.height

            HoverHandler {
                id: meterHover
            }
        }

        // The clock's own target, placed the same way: the digits are two
        // characters in a narrow strip, and the calendar is reached by aiming
        // at the bottom of the rail rather than at them exactly.
        Item {
            x: (railContent.width - width) / 2
            y: bottom.y + clock.y
            width: Theme.rail
            height: clock.height

            HoverHandler {
                id: clockHover
            }
        }
    }

    // Only while the rail is out: in the sliver the meters are six pixels wide
    // and a panel beside them would be most of what is on screen.
    RailTip {
        modelData: bar.modelData
        anchorRight: bar.anchorRight
        markY: bar.tipY
        shown: meterHover.hovered && bar.expanded
    }

    // Same rule as the meter tip: only while the rail is out, since collapsed
    // the clock is a sliver of skeleton with no digits to expand on.
    CalendarTip {
        modelData: bar.modelData
        anchorRight: bar.anchorRight
        markY: bar.clockY
        shown: clockHover.hovered && bar.expanded
    }
}
