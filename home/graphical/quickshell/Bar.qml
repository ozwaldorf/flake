pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "widgets"
import "services"

// Vertical rail anchored to the outward facing screen edge. Only the sliver is
// an exclusive zone, so tiled windows never reflow when the rail wakes; the
// rail draws over the desktop instead of pushing it.
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
    onExpandedChanged: SysMeters.watch(expanded)

    Component.onDestruction: {
        if (expanded)
            SysMeters.watch(false);
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
    //
    // Room past the rail for the shadow it casts inward. Without it the window
    // is exactly the rail's own width, so at full expansion the rail fills it
    // and the shadow falls entirely outside.
    shadowRoom: 20

    implicitWidth: Theme.rail + shadowRoom

    // 0 collapsed, 1 expanded; every width on the rail, and the toasts beside
    // it, follow this one value
    property real reveal: expanded ? 1 : 0

    // Glided rather than eased: a pointer flicking in and out of the rail
    // turns it around mid travel, and every width below follows this one value.
    Behavior on reveal {
        Glide {}
    }

    // visible width of the rail within the fixed surface
    readonly property real railWidth: Theme.sliver + (Theme.rail - Theme.sliver) * reveal

    // The rail hugs the outward edge, so the content is inset from the other
    // side, measured from the window's own edge, which reaches past the rail
    // to give the shadow somewhere to fall.
    readonly property real railX: bar.anchorRight ? width - railWidth : 0

    // Client side blur, following the visible rail rather than the surface,
    // which is a fixed full width strip.
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

        // Cast inward only: the rail runs the height of the screen against its
        // own edge, so the other three sides have nothing to fall onto. Grows
        // as the rail wakes, which is what makes it read as coming forward
        // rather than only getting wider.
        Rectangle {
            id: railShadow

            // Barely wider on expand: spreading the same darkness over more
            // distance reads as less of it, not more, so the depth comes from
            // the alpha and the width only follows a little.
            readonly property real spread: 14 + 6 * bar.reveal

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: bar.anchorRight ? undefined : parent.right
            anchors.right: bar.anchorRight ? parent.left : undefined
            width: spread

            // Falls away quickly rather than evenly across its width: a linear
            // ramp is still visibly dark where it ends, which reads as a band
            // with an edge rather than a shadow fading out. A midpoint well
            // under half the peak puts most of the falloff near the rail.
            readonly property real peak: 0.14 + 0.16 * bar.reveal

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: Qt.alpha("black", bar.anchorRight ? 0 : railShadow.peak)
                }
                GradientStop {
                    position: bar.anchorRight ? 0.65 : 0.35
                    color: Qt.alpha("black", railShadow.peak * 0.22)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha("black", bar.anchorRight ? railShadow.peak : 0)
                }
            }
        }

        // hairline on the inward facing edge, whichever side that is
        Rectangle {
            anchors.right: bar.anchorRight ? undefined : parent.right
            anchors.left: bar.anchorRight ? parent.left : undefined
            width: 1
            height: parent.height
            color: Theme.surface0
            opacity: bar.expanded ? 1 : 0

            Behavior on opacity {
                Fade {}
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
