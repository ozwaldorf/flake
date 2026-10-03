pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "widgets"
import "services"

// Vertical rail anchored to the outward facing screen edge. It sits behind the
// desktop rather than over it: waking the rail widens the exclusive zone so the
// windows move aside, the wallpaper slides with them, and the rail is revealed
// in the gap they leave. Opening a drawer widens it again, by the width of the
// panel it holds: the control centre from the top corner, the monitor and
// calendar from the foot.
EdgeWindow {
    id: bar

    // whether the control centre is the drawer that is open, for the mark
    // that opens it
    property bool panelOpen: false

    // how far the open drawer reaches past the rail, or 0 with none open; the
    // rail is held out while one is, so moving toward it does not collapse it
    property real drawerWidth: 0
    readonly property bool expanded: railHovered || drawerWidth > 0

    // whether the pointer is on the corner zone that opens the panel
    readonly property bool cornerHovered: cornerHover.hovered

    // whether the pointer is on the foot of the rail, which opens the other
    readonly property bool bottomHovered: bottomHover.hovered

    // whether the pointer is anywhere on the rail, undebounced
    readonly property bool pointerInside: rawHover.hovered

    // A tap on the corner or the foot, which open their drawers, and one
    // anywhere else on the rail, which closes it. The workspace marks take
    // their own clicks.
    signal cornerTapped
    signal bottomTapped
    signal railTapped

    // a tap on the open drawer's own ground, past the rail, between and
    // around whatever the drawer holds
    signal drawerTapped

    // the pointer pushed into the screen's own corner, which opens the
    // overview and the drawer together, in place of niri's hot corner
    signal hotCornerEntered

    // sample the meters faster while this rail is out; released on destruction
    // so unplugging a monitor mid hover does not leave the count raised
    onExpandedChanged: SysMeters.watch(expanded)

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
    exclusiveZone: drawerWidth > 0 ? Theme.rail + drawerWidth : expanded ? Theme.rail : Theme.sliver

    // The rail and as much of the drawer as is out. The drawer's own window
    // sits over it and takes the cards; this holds the hover across the empty
    // space between and below them, so it does not read as leaving.
    mask: Region {
        x: backdrop.x
        y: 0
        width: backdrop.width
        height: bar.height
    }

    // The surface stays at full width and the content animates inside it.
    // Animating implicitWidth means a right anchored surface is resized and
    // repositioned every frame, since its origin is derived from the width, and
    // those two commits are not atomic: the surface can present at the new size
    // before the new position lands, which shows as a gap at the screen edge.
    shadowRoom: 0

    implicitWidth: Theme.rail + Theme.drawerWidth + Theme.railInset * 2

    // On niri's spring, so the rail and the windows it pushes move as one. Two
    // of them rather than one over the total: the rail's marks morph on its
    // own 0 to 1, and the spring being linear, the sum still tracks niri's
    // single retargeted one.
    Spring {
        id: railSpring
        target: bar.expanded ? 1 : 0
    }

    Spring {
        id: drawerSpring
        target: bar.drawerWidth
    }

    // 0 collapsed, 1 expanded; every width on the rail, and the toasts beside
    // it, follow this one value
    readonly property real reveal: railSpring.value

    // visible width of the rail within the fixed surface
    readonly property real railWidth: Theme.sliver + (Theme.rail - Theme.sliver) * reveal

    // how far the desktop is pushed from the screen edge: the rail and as much
    // of the drawer as is out
    readonly property real pushWidth: railWidth + drawerSpring.value

    // The rail hugs the outward edge, so the content is inset from the other
    // side, measured from the window's own edge.
    readonly property real railX: bar.anchorRight ? width - railWidth : 0

    // Explicitly empty rather than unset: a surface kept across a reload holds
    // on to whatever region it was last given, and the transparent part of the
    // strip would go on blurring the wallpaper sliding under it.
    BackgroundEffect.blurRegion: Region {}

    // Three layers, front to back: the desktop, the rail, and the drawer
    // under the rail. All opaque, since there is nothing further back to show
    // through. Clipped to as far as the desktop has slid, which is all of
    // them that is uncovered.
    Item {
        id: backdrop

        x: bar.anchorRight ? bar.width - width : 0
        y: 0
        width: bar.pushWidth
        height: parent.height
        clip: true

        // the drawer, the deepest of the three: darkest, and shaded by both
        // layers over it
        Rectangle {
            anchors.fill: parent
            color: Theme.mantle
        }

        // The rail, a layer up from the drawer: lighter, and casting onto the
        // drawer as it opens out from under it.
        Rectangle {
            id: railLayer

            x: bar.anchorRight ? parent.width - width : 0
            width: bar.railWidth
            height: parent.height
            color: Theme.base
        }

        // only once there is drawer for it to fall on
        EdgeShadow {
            x: bar.anchorRight ? railLayer.x - width : railLayer.x + railLayer.width
            side: bar.anchorRight ? "right" : "left"
            peak: 0.5 * Theme.clamp01((bar.pushWidth - bar.railWidth) / 24)
        }

        // The desktop, over both: at the drawer's far edge while it is out,
        // on the rail's edge once it has closed. Light over the rail alone,
        // which sits just under it, and deepening as the drawer opens, so the
        // desktop reads as lifting further away the more lies beneath it.
        EdgeShadow {
            x: bar.anchorRight ? 0 : parent.width - width
            side: bar.anchorRight ? "left" : "right"
            peak: bar.recess
        }

        // The rest of the recess the bar sits in, the screen's own edges, cast
        // the same as the desktop's so the whole of it reads as sunk below.
        EdgeShadow {
            x: bar.anchorRight ? parent.width - width : 0
            side: bar.anchorRight ? "right" : "left"
            peak: bar.recess
        }

        EdgeShadow {
            side: "top"
            peak: bar.recess
        }

        EdgeShadow {
            y: parent.height - height
            side: "bottom"
            peak: bar.recess
        }
    }

    // how deep the bar sits under the desktop, and so how dark the edges of
    // its recess: light with the rail alone, deepening as a drawer opens
    readonly property real recess: 0.2 + 0.1 * reveal + 0.25 * Theme.clamp01((pushWidth - railWidth) / Theme.drawerWidth)

    // A shadow cast from an edge onto the layer beneath it, darkest along the
    // given side. Falls away quickly rather than evenly across its depth: a
    // linear ramp is still visibly dark where it ends, which reads as a band
    // with an edge rather than a shadow fading out.
    component EdgeShadow: Rectangle {
        id: shadow

        // the side it is darkest along: left, right, top or bottom
        required property string side
        property real peak: 0.4

        readonly property bool across: side === "left" || side === "right"

        // darkest at the start of the gradient rather than its end
        readonly property bool fromStart: side === "left" || side === "top"

        width: across ? 18 : parent.width
        height: across ? parent.height : 18

        gradient: Gradient {
            orientation: shadow.across ? Gradient.Horizontal : Gradient.Vertical

            GradientStop {
                position: 0
                color: Qt.alpha("black", shadow.fromStart ? shadow.peak : 0)
            }
            GradientStop {
                position: shadow.fromStart ? 0.35 : 0.65
                color: Qt.alpha("black", shadow.peak * 0.22)
            }
            GradientStop {
                position: 1
                color: Qt.alpha("black", shadow.fromStart ? 0 : shadow.peak)
            }
        }
    }

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
        id: corner

        x: bar.railX
        y: 0
        width: bar.railWidth
        height: Theme.railPad + gear.height + Theme.railItemGap

        HoverHandler {
            id: cornerHover
        }
    }

    // The corner pixels themselves, inside the corner zone: only a pointer
    // pushed all the way in reaches them, so the drawer can be had alone.
    Item {
        x: bar.anchorRight ? bar.width - width : 0
        y: 0
        width: 2
        height: 2

        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    bar.hotCornerEntered();
            }
        }
    }

    // Opening the monitor and calendar: the foot of the rail, from just above
    // the meters down to the screen edge, the counterpart of the corner. Summed
    // from the group's offsets rather than mapped, which would not follow it.
    Item {
        id: foot

        x: bar.railX
        y: railContent.y + bottom.y - Theme.railItemGap
        width: bar.railWidth
        height: bar.height - y

        HoverHandler {
            id: bottomHover
        }
    }

    // One handler for the whole rail, split by where the tap landed: two on
    // nested items would both see a tap on the corner.
    TapHandler {
        onTapped: eventPoint => {
            const x = eventPoint.position.x;
            if (x < bar.railX || x > bar.railX + bar.railWidth) {
                bar.drawerTapped();
                return;
            }
            if (eventPoint.position.y < corner.height)
                bar.cornerTapped();
            else if (eventPoint.position.y >= foot.y)
                bar.bottomTapped();
            else
                bar.railTapped();
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
    }
}
