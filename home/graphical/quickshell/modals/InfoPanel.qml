pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../widgets"
import "../services"

// The system monitor and the month, in the drawer opened from the foot of the
// rail: the machine at the head, and a grid of wells held against the bottom,
// each reading in the form that suits it. Loads as a big figure over the last
// couple of minutes, capacities as a run of blocks, rates as a mirror of down
// over up, the month at the foot beside the clock.
ModalPanel {
    id: root


    readonly property bool live: revealWidth > Theme.rail && Math.abs(pageX) < width

    // processes are sampled only while this is showing them
    onLiveChanged: SysMeters.watchProcesses(live)
    Component.onDestruction: {
        if (live)
            SysMeters.watchProcesses(false);
    }

    // The readings take up whatever the head leaves them: the gap between the
    // host and the stack is shared out over the four rows of charts, so they
    // grow on a tall screen rather than leaving the middle of the drawer
    // empty. The month keeps its own height.
    readonly property real naturalStack: (112 + 100 + 100 + 112) + calendar.implicitHeight + gap * 4
    readonly property real stretch: Math.max(0, (layout.parent.height - host.height - gap - naturalStack) / 4)

    // a switch moves the generation under a running session, so the host's
    // details are read again whenever the drawer opens
    onShownChanged: {
        if (shown)
            SysMeters.rescanHost();
    }
    readonly property bool gpu: SysMeters.gpuAvailable

    // the laptop's own cell, rather than the combined display device, which
    // carries no health
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery) ?? null

    readonly property real gap: Theme.spaceXs
    // the two widths a row splits into
    readonly property real narrow: Math.round((panelWidth - gap) * 0.42)
    readonly property real wide: panelWidth - gap - narrow

    // A figure set large, with what it is out of beside it, small, on the
    // same baseline.
    component Figure: Row {
        id: figure

        required property string value
        property string suffix: ""

        spacing: 6

        Label {
            id: big

            text: figure.value
            figures: true
            font.pixelSize: 28
        }

        Label {
            anchors.baseline: big.baseline
            text: figure.suffix
            figures: true
            color: Theme.overlay0
        }
    }

    // A load: the figure now, large, over the line it has drawn lately.
    component LoadWell: Well {
        id: load

        required property string kind
        required property string figure
        property string suffix: ""

        // room kept beside the chart for whatever sits in the far corner
        property real chartRight: 0

        readonly property var def: Meters.defs[kind]

        title: def.label
        icon: def.icon
        tint: def.fill
        height: 100

        backdrop: Sparkline {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: load.chartRight
            height: parent.height * 0.62
            showAxis: false
            wash: false
            glow: true
            lineWidth: 1.6

            values: root.live ? Meters.history(load.kind) : []
            skipLeading: SysMeters.warmup
            stroke: load.def.fill
            format: Meters.format(load.kind)
            interval: SysMeters.historyInterval
            limit: Meters.ceiling(load.kind)
        }

        Figure {
            value: load.figure
            suffix: load.suffix
        }
    }

    // A capacity as a block of the rail's own marks: how much of it is taken
    // reads as how many are lit, filling from the bottom corner along each row
    // and then up, like a level rising. Set in the corner of the tile whose
    // activity it belongs to, beside that activity's chart.
    component Blocks: Item {
        id: capacity

        required property string kind

        readonly property var def: Meters.defs[kind]
        property int columns: 6
        // as many rows as the tile is tall enough for, so the block grows
        // with the tile rather than leaving it empty above
        readonly property int rows: Math.max(1, Math.floor((parent.height + root.blockGap) / (root.blockSize + root.blockGap)))
        readonly property int lit: Math.round(Meters.share(kind) * columns * rows)

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.blockSize * columns + root.blockGap * (columns - 1)
        height: root.blockSize * rows + root.blockGap * (rows - 1)

        Repeater {
            model: capacity.columns * capacity.rows

            Rectangle {
                required property int index

                // counted from the bottom right corner, right to left along a
                // row, then the row above
                x: capacity.width - root.blockSize - (index % capacity.columns) * (root.blockSize + root.blockGap)
                y: capacity.height - root.blockSize - Math.floor(index / capacity.columns) * (root.blockSize + root.blockGap)
                width: root.blockSize
                height: root.blockSize
                radius: 2
                color: index < capacity.lit ? capacity.def.fill : Qt.alpha(Theme.surface0, 0.8)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.levelDuration
                    }
                }
            }
        }
    }

    readonly property real blockSize: 10
    readonly property real blockGap: 3

    // What a block takes off the side of a tile, measured from the backdrop's
    // edge, so a chart beside it stops short of the blocks.
    function blocksRoom(columns) {
        return Theme.padCard - 5 + blockSize * columns + blockGap * (columns - 1) + Theme.space;
    }

    // what a capacity reads, set against the tile's heading
    function capacityNote(kind) {
        return SysMeters.formatBytes(Meters.used(kind)) + " / " + SysMeters.formatBytes(Meters.total(kind));
    }

    // A pair of rates, down over up: one line above a centre rule and its
    // mirror below it, so the two read against each other at a glance.
    component FlowWell: Well {
        id: flow

        required property string kind

        // room kept beside the chart for whatever sits in the far corner
        property real chartRight: 0

        readonly property var def: Meters.defs[kind]

        title: def.label
        icon: def.icon
        tint: def.fill
        height: 104

        backdrop: Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: flow.chartRight
            height: parent.height * 0.6

            Sparkline {
                width: parent.width
                height: parent.height / 2
                showAxis: false
                wash: false
                glow: true

                values: root.live ? Meters.history(flow.kind) : []
                skipLeading: SysMeters.warmup
                stroke: flow.def.fill
                interval: SysMeters.historyInterval
            }

            Rectangle {
                y: parent.height / 2
                width: parent.width
                height: 1
                color: Qt.alpha(Theme.surface1, 0.6)
            }

            Sparkline {
                id: upward

                y: parent.height / 2
                width: parent.width
                height: parent.height / 2
                showAxis: false
                wash: false
                glow: true

                values: root.live ? Meters.secondHistory(flow.kind) : []
                skipLeading: SysMeters.warmup
                stroke: Meters.secondFill
                interval: SysMeters.historyInterval

                transform: Scale {
                    origin.y: upward.height / 2
                    yScale: -1
                }
            }
        }

        Column {
            spacing: 1

            Label {
                text: Meters.detail(flow.kind)
                figures: true
                color: flow.def.fill
            }

            Label {
                text: Meters.secondDetail(flow.kind)
                figures: true
                color: Meters.secondFill
            }
        }
    }

    // Who and what this is: the distribution's mark beside user at host,
    // how long it has been up, and the machine down to its parts as a short
    // spec sheet. Held at the head of the drawer, apart from the readings
    // gathered at its foot.
    Well {
        id: host

        readonly property color accent: Meters.defs.summary.fill

        // Vendor strings trimmed to the part that tells one apart: no
        // trademark marks or maker, no clock speed the load already speaks
        // to, no model code after the name.
        function tidy(s) {
            return s.replace(/\((R|TM|tm)\)/g, "").replace(/\b(CPU|GPU|Intel|AMD|NVIDIA|GeForce)\b/g, "").replace(/@.*$/, "").replace(/\s+-\s+.*$/, "").replace(/\s+/g, " ").trim();
        }

        readonly property var cpu: /^(.*) \((\d+)\)$/.exec(SysMeters.cpuModel)

        // the nixpkgs date and revision NixOS stamps into its version
        readonly property var nixpkgs: /\.(\d{4})(\d{2})(\d{2})\.([0-9a-f]+)/.exec(SysMeters.nixosVersion)

        // How long ago, to the same coarseness as the uptime. Read against
        // the uptime so it moves on with it rather than holding the moment
        // the binding first ran.
        function ago(epoch) {
            const now = Date.now() / 1000 + SysMeters.uptime * 0;
            return SysMeters.formatUptime(Math.max(0, now - epoch)) + " ago";
        }

        // Whole days back to a date known only to the day, as the nixpkgs
        // revision is: hours would claim a precision it does not have.
        function daysAgo(date) {
            const today = new Date(Date.now() + SysMeters.uptime * 0);
            today.setHours(0, 0, 0, 0);
            const days = Math.round((today - date) / 86400000);
            return days <= 0 ? "today" : days === 1 ? "1 day ago" : days + " days ago";
        }

        // Only what came back, so a machine without a battery or a card
        // closes up rather than listing blanks.
        readonly property var specs: [["OS", SysMeters.osName], ["Kernel", SysMeters.kernel ? "Linux " + SysMeters.kernel : ""], ["Processor", cpu ? tidy(cpu[1]) + " \u00b7 " + cpu[2] + "T" : tidy(SysMeters.cpuModel)], ["Graphics", tidy(SysMeters.gpuModel)], ["Generation", SysMeters.generation > 0 ? "#" + SysMeters.generation + " \u00b7 " + ago(SysMeters.generationTime) : ""], ["Nixpkgs", nixpkgs ? nixpkgs[4] + " \u00b7 " + daysAgo(new Date(nixpkgs[1], nixpkgs[2] - 1, nixpkgs[3])) : ""], ["Shell", SysMeters.shellRelease], ["WM", SysMeters.wmRelease]].filter(f => f[1] !== "")

        anchors.top: parent.top
        width: parent.width
        height: sheet.y + sheet.height + paddingTop + padding
        padding: Theme.space
        paddingTop: Theme.spaceSm

        Text {
            id: logo

            anchors.left: parent.left
            anchors.top: parent.top
            text: Meters.defs.summary.icon
            font.family: Theme.iconFont
            font.pixelSize: 40
            color: host.accent
        }

        Column {
            id: who

            anchors.left: logo.right
            anchors.verticalCenter: logo.verticalCenter
            anchors.leftMargin: Theme.spaceSm
            anchors.right: uptime.left
            anchors.rightMargin: Theme.spaceXs
            spacing: 3

            Label {
                width: parent.width
                text: SysMeters.userName + "@" + SysMeters.hostName
                font.pixelSize: 15
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                visible: text !== ""
                text: host.tidy(SysMeters.hostModel)
                color: Theme.overlay1
                elide: Text.ElideRight
            }
        }

        // how long it has been up, as a tag on the corner
        Rectangle {
            id: uptime

            anchors.right: parent.right
            anchors.verticalCenter: logo.verticalCenter
            width: upLabel.implicitWidth + Theme.spaceSm * 2
            height: upLabel.implicitHeight + 8
            radius: height / 2
            color: Qt.alpha(host.accent, 0.14)

            Label {
                id: upLabel

                anchors.centerIn: parent
                text: "up " + SysMeters.formatUptime(SysMeters.uptime)
                figures: true
                color: host.accent
            }
        }

        Rectangle {
            id: rule

            anchors.top: logo.bottom
            anchors.topMargin: Theme.spaceSm
            width: parent.width
            height: 1
            color: Qt.alpha(Theme.surface1, 0.6)
        }

        // A caption over each value, two to a line: read down a column as
        // a spec sheet rather than across as a list.
        Grid {
            id: sheet

            anchors.top: rule.bottom
            anchors.topMargin: Theme.space
            width: parent.width
            columns: 2
            columnSpacing: Theme.spaceLg
            rowSpacing: Theme.space

            Repeater {
                model: host.specs

                Column {
                    id: spec

                    required property var modelData

                    width: (sheet.width - sheet.columnSpacing) / 2
                    spacing: 2

                    Label {
                        text: spec.modelData[0].toUpperCase()
                        font.pixelSize: 8
                        font.letterSpacing: 1.2
                        color: Theme.overlay0
                    }

                    Label {
                        width: parent.width
                        text: spec.modelData[1]
                        figures: true
                        color: Theme.subtext1
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Column {
        id: layout

        anchors.bottom: parent.bottom
        width: parent.width
        spacing: root.gap

        // The rest pair a wide tile with a narrow one, the wide side moving
        // between rows so the grid does not settle into columns.
        Row {
            spacing: root.gap

            LoadWell {
                kind: "cpu"
                figure: SysMeters.cpu + "%"
                width: root.gpu ? root.narrow : parent.width
                height: 112 + root.stretch
            }

            // the card's load, and its memory in the corner
            LoadWell {
                visible: root.gpu
                kind: "gpu"
                figure: SysMeters.gpu + "%"
                width: root.wide
                height: 112 + root.stretch
                note: "VRAM  " + root.capacityNote("vram")
                chartRight: root.blocksRoom(4)

                Blocks {
                    kind: "vram"
                    columns: 4
                }
            }
        }

        Row {
            spacing: root.gap

            // The busiest processes now, each a line with its share of the
            // processor behind it as a faint bar, so the list reads as a
            // ranking at a glance.
            Well {
                id: processes

                readonly property real lineHeight: 15

                title: "Processes"
                icon: Theme.iconCpu
                tint: Theme.mauve
                width: root.wide
                height: 100 + root.stretch

                Column {
                    width: parent.width
                    spacing: 3

                    Repeater {
                        // as many as the tile has room for
                        model: SysMeters.processes.slice(0, Math.max(1, Math.floor((processes.height - Theme.padCard * 2 - 27) / (processes.lineHeight + 3))))

                        Item {
                            id: proc

                            required property var modelData

                            width: parent.width
                            height: processes.lineHeight

                            Rectangle {
                                width: parent.width * Theme.clamp01(proc.modelData.cpu / 100)
                                height: parent.height
                                radius: 3
                                color: Qt.alpha(Meters.defs.cpu.fill, 0.18)
                            }

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.right: share.left
                                anchors.rightMargin: Theme.spaceXs
                                anchors.verticalCenter: parent.verticalCenter
                                text: proc.modelData.name
                                color: Theme.subtext0
                                elide: Text.ElideRight
                            }

                            Label {
                                id: share

                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: proc.modelData.cpu.toFixed(1) + "%"
                                figures: true
                                color: Theme.overlay1
                            }
                        }
                    }
                }
            }

            // what is taken large, what it is out of against the heading
            LoadWell {
                kind: "memory"
                figure: SysMeters.formatBytes(SysMeters.memoryUsed)
                note: SysMeters.formatBytes(SysMeters.memoryTotal)
                width: root.narrow
                height: 100 + root.stretch
            }
        }

        Row {
            spacing: root.gap

            // Temperatures as columns of mercury, the processor and, when
            // there is one, the card beside it.
            Well {
                title: "Heat"
                icon: Theme.iconCpu
                tint: Theme.peach
                width: root.battery ? root.narrow : parent.width
                height: 100 + root.stretch

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    spacing: 22

                    Repeater {
                        model: root.gpu ? [["CPU", SysMeters.cpuTemperature, Meters.defs.cpu.fill], ["GPU", SysMeters.gpuTemperature, Meters.defs.gpu.fill]] : [["CPU", SysMeters.cpuTemperature, Meters.defs.cpu.fill]]

                        Column {
                            id: thermo

                            required property var modelData

                            // 30 to 100 degrees across the column, which is
                            // the range a desktop part actually moves through
                            readonly property real level: Theme.clamp01((modelData[1] - 30) / 70)

                            height: parent.height
                            spacing: 4

                            Label {
                                id: reading

                                anchors.horizontalCenter: parent.horizontalCenter
                                text: SysMeters.fahrenheit(thermo.modelData[1]) + "°"
                                figures: true
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 8
                                height: parent.height - reading.height - name.height - parent.spacing * 2
                                radius: width / 2
                                color: Qt.alpha(Theme.surface0, 0.8)

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(width, parent.height * thermo.level)
                                    radius: width / 2
                                    color: thermo.level > 0.75 ? Theme.red : thermo.modelData[2]

                                    Behavior on height {
                                        NumberAnimation {
                                            duration: Theme.levelDuration
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }

                            Label {
                                id: name

                                anchors.horizontalCenter: parent.horizontalCenter
                                text: thermo.modelData[0]
                                font.pixelSize: 9
                                color: Theme.overlay0
                            }
                        }
                    }
                }
            }

            // Charge as a figure and as the cell it is in, with what it is
            // doing and how long that leaves along the foot.
            Well {
                id: battery

                readonly property var device: root.battery
                readonly property real level: device ? device.percentage : 0
                readonly property int power: device ? device.state : UPowerDeviceState.Unknown
                readonly property bool charging: power === UPowerDeviceState.Charging
                readonly property color fill: level < 0.15 ? Theme.red : level < 0.35 ? Theme.yellow : Theme.green

                readonly property string status: {
                    switch (power) {
                    case UPowerDeviceState.Charging:
                        return "charging";
                    case UPowerDeviceState.Discharging:
                        return "on battery";
                    case UPowerDeviceState.FullyCharged:
                        return "full";
                    case UPowerDeviceState.PendingCharge:
                        return "plugged in";
                    default:
                        return "";
                    }
                }

                // How long the current direction runs, and at what rate: UPower
                // reports nothing for either while the cell is holding.
                readonly property string detail: {
                    if (!device)
                        return "";
                    const parts = [];
                    if (charging && device.timeToFull > 0)
                        parts.push(SysMeters.formatUptime(device.timeToFull) + " to full");
                    else if (power === UPowerDeviceState.Discharging && device.timeToEmpty > 0)
                        parts.push(SysMeters.formatUptime(device.timeToEmpty) + " left");
                    if (Math.abs(device.changeRate) > 0.05)
                        parts.push(Math.abs(device.changeRate).toFixed(1) + " W");
                    return parts.length > 0 ? parts.join(" · ") : "holding charge";
                }

                visible: device !== null
                title: "Battery"
                icon: String.fromCodePoint(0xf240)
                tint: fill
                note: device && device.healthSupported ? "health " + Math.round(device.healthPercentage) + "%" : ""
                width: root.wide
                height: 100 + root.stretch

                Figure {
                    value: Math.round(battery.level * 100) + "%"
                    suffix: battery.status
                }

                Label {
                    anchors.bottom: parent.bottom
                    text: battery.detail
                    figures: true
                    color: Theme.overlay1
                }

                // the cell itself, filled to the charge, with its terminal
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 66
                    height: 30

                    Rectangle {
                        id: cell

                        width: parent.width - 5
                        height: parent.height
                        radius: 6
                        color: "transparent"
                        border.width: 1.5
                        border.color: Theme.surface2

                        Rectangle {
                            id: charge

                            x: 4
                            y: 4
                            width: Math.max(2, (parent.width - 8) * battery.level)
                            height: parent.height - 8
                            radius: 3
                            color: battery.fill

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.levelDuration
                                    easing.type: Easing.OutQuad
                                }
                            }

                            // breathing while it charges
                            SequentialAnimation on opacity {
                                running: battery.charging && root.live
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) charge.opacity = 1

                                NumberAnimation {
                                    to: 0.55
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 900
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: cell.right
                        anchors.leftMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 10
                        radius: 1.5
                        color: Theme.surface2
                    }
                }
            }
        }

        Row {
            spacing: root.gap

            // what the disk is reading and writing, and how full it is in the
            // corner
            FlowWell {
                kind: "io"
                title: "Disk"
                width: root.wide
                height: 112 + root.stretch
                note: root.capacityNote("disk")
                chartRight: root.blocksRoom(6)

                Blocks {
                    kind: "disk"
                }
            }

            FlowWell {
                kind: "network"
                width: root.narrow
                height: 112 + root.stretch
            }
        }

        MonthCalendar {
            id: calendar

            width: parent.width
        }
    }
}
