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
    // Room past the rail for the shadow it casts inward. Without it the window
    // is exactly the rail's own width, so at full expansion the rail fills it
    // and the shadow falls entirely outside: it showed while collapsed, where
    // the rest of the window was still free, and vanished as it opened.
    readonly property real shadowRoom: 20

    implicitWidth: Theme.rail + shadowRoom

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
    // measured from the window's own edge, which now reaches past the rail to
    // give the shadow somewhere to fall
    readonly property real railX: bar.anchorRight ? width - railWidth : 0

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
                NumberAnimation {
                    duration: Theme.fadeDuration
                }
            }
        }
    }

    // ---- meter tooltip ----
    //
    // The meters say how loaded things are but not what they are, and the rail
    // has no room to label them. Hovering anywhere in the group opens all
    // three: they are read against each other more often than alone, and
    // moving between them to compare meant losing the one just looked at.
    //
    // Bound rather than copied, so the readings keep counting while the tip is
    // up instead of freezing at whatever they were when the pointer arrived.
    // Constant: only which meters there are and how each is drawn, never a
    // reading. A list rebuilt when a reading changes is a new array every
    // sample, and a repeater over it tears down and recreates its delegates
    // each time, restarting whatever animation they were running.
    //
    // The readings come through the kind, which the chips resolve themselves.
    // Without the driver there is no reading to show, so those entries are
    // dropped rather than left as chips that never fill.
    // Rows are numbered from the bottom, where the wide end sits against the
    // meters. Widths shape the wedge: each row is narrower than the one below
    // it, and the sizes vary within a row so the stack does not read as a grid.
    //
    // Without the driver there is no GPU reading to show, so those entries drop
    // out. That empties the top row rather than leaving a gap in it, since the
    // pair sharing that row are both the card's.
    readonly property var tipMeters: allMeters.filter(m => SysMeters.gpuAvailable || (m.kind !== "gpu" && m.kind !== "vram"))

    readonly property var allMeters: [
        // row 0, against the meters: the widest, at 480
        {
            kind: "memory",
            icon: Theme.iconMemory,
            label: "Memory",
            fill: Theme.mauve,
            row: 0,
            width: 150
        },
        {
            kind: "io",
            icon: Theme.iconDisk,
            label: "Disk I/O",
            fill: Theme.yellow,
            row: 0,
            width: 180
        },
        {
            kind: "disk",
            icon: Theme.iconDisk,
            label: "Disk",
            fill: Theme.yellow,
            row: 0,
            width: 134,
            dial: true
        },
        // row 1, at 410
        {
            kind: "network",
            icon: Theme.iconNetwork,
            label: "Network",
            fill: Theme.teal,
            row: 1,
            width: 250
        },
        {
            kind: "cpu",
            icon: Theme.iconCpu,
            label: "CPU",
            fill: Theme.sapphire,
            // a percentage cannot pass a hundred, so the axis must not either
            limit: 100,
            row: 1,
            width: 152
        },
        // row 2, the narrow end at 318
        {
            kind: "gpu",
            icon: Theme.iconGpu,
            label: "GPU",
            fill: Theme.green,
            limit: 100,
            row: 2,
            width: 176
        },
        {
            kind: "vram",
            icon: Theme.iconGpu,
            label: "VRAM",
            fill: Theme.green,
            row: 2,
            width: 134,
            dial: true
        },
        // The apex: what the machine is rather than what it is doing, which is
        // read once on the way past rather than watched.
        {
            kind: "summary",
            icon: Theme.iconHost,
            label: "System",
            fill: Theme.overlay2,
            row: 3,
            width: 225
        }
    ]

    // Centre of the meter group, so the tip opens level with what it describes.
    // Summed from the items' own geometry rather than mapped: a mapToItem call
    // does not re-evaluate when they move.
    readonly property real tipY: railContent.y + bottom.y + meters.y + meters.height / 2

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
        id: railContent

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
                id: meters

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.meterGap

                LoadMeter {
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.cpu
                    fill: Theme.sapphire
                }

                LoadMeter {
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.memory
                    fill: Theme.mauve
                }

                // Down from the base and up stacked on it, so the mark says
                // which direction the traffic is in rather than only that
                // there is some.
                LoadMeter {
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.networkDown
                    fill: Theme.teal
                    secondValue: SysMeters.networkUp
                    secondFill: Theme.sky
                }

                LoadMeter {
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.gpu
                    fill: Theme.green
                    visible: SysMeters.gpuAvailable
                }

                LoadMeter {
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: bar.expanded
                    value: SysMeters.disk
                    fill: Theme.yellow
                }
            }

            Clock {
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: bar.expanded
            }
        }

        // One target over the whole meter group rather than one per meter: the
        // tip shows all three, so which one the pointer is on does not matter,
        // and travelling between them never drops it. Spans the rail so the
        // marks are not what has to be hit.
        //
        // Placed by summing the group's offsets rather than by mapToItem,
        // which is a one shot call with no dependency tracking: it answered
        // while the column was still at the origin and left the target
        // stranded in the corner. A Column refuses vertical anchors on its
        // children besides, so this sits outside the columns entirely.
        Item {
            x: (railContent.width - width) / 2
            y: bottom.y + meters.y
            width: Theme.rail
            height: meters.height

            HoverHandler {
                id: meterHover
            }
        }
    }

    // Only while the rail is out: in the sliver the meters are six pixels wide
    // and a panel beside them would be most of what is on screen.
    RailTip {
        screenData: bar.modelData
        anchorRight: bar.anchorRight
        meters: bar.tipMeters
        markY: bar.tipY
        shown: meterHover.hovered && bar.expanded
    }
}
