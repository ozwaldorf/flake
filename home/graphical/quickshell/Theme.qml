pragma Singleton

import QtQuick
import Quickshell

// Carburetor Mocha, matching the palette used by the rest of the desktop.
Singleton {
    readonly property color crust: "#000000"
    readonly property color mantle: "#0b0b0b"
    readonly property color base: "#161616"
    readonly property color surface0: "#262626"
    readonly property color surface1: "#393939"
    readonly property color surface2: "#525252"
    readonly property color overlay0: "#6f6f6f"
    readonly property color overlay1: "#8d8d8d"
    readonly property color overlay2: "#a8a8a8"
    readonly property color subtext0: "#c6c6c6"
    readonly property color subtext1: "#e0e0e0"
    readonly property color text: "#f4f4f4"

    readonly property color blue: "#4589ff"
    readonly property color sapphire: "#78a9ff"
    readonly property color sky: "#82cffe"
    readonly property color mauve: "#d4bbff"
    readonly property color teal: "#3ddbd9"
    readonly property color red: "#fa4d56"
    readonly property color peach: "#fe832b"
    readonly property color green: "#42be65"
    readonly property color yellow: "#fddc69"

    readonly property string font: "Berkeley Mono"

    // Berkeley Mono carries no icons, so glyphs come from the nerd font.
    // Codepoints verified present in FiraCodeNerdFont-Regular's cmap.
    readonly property string iconFont: "FiraCode Nerd Font"
    readonly property int iconSize: 15
    readonly property string iconGear: String.fromCodePoint(0xf013)
    readonly property string iconClose: String.fromCodePoint(0xf00d)

    // matches hyprland decoration.rounding
    readonly property int rounding: 10

    // surface fill shared with foot: background 161616 at alpha 0.8, blurred
    // client side via ext-background-effect-v1
    readonly property color surfaceFill: Qt.rgba(base.r, base.g, base.b, 0.8)

    readonly property int sliver: 6
    readonly property int rail: 44
    readonly property int modalWidth: 340

    // spacing scale; everything in the modals derives from these rather than
    // carrying its own magic numbers
    readonly property int spaceXs: 6
    readonly property int spaceSm: 10
    readonly property int space: 16
    readonly property int spaceLg: 22

    // Rail whitespace. Constant across both forms so expanding never shifts
    // anything vertically. Related marks sit at railItemGap; only genuinely
    // separate groups get railGroupGap.
    readonly property int railGroupGap: 22
    readonly property int railItemGap: 6

    // gap between workspace blocks, equal to the block size
    readonly property int wsGap: 12

    // System meters: one per row down the rail, sized and spaced exactly like
    // the workspace marks so the two groups read as one system.
    readonly property int meterWidth: wsWidth
    readonly property int meterHeight: wsFocusedLength
    readonly property int meterGap: wsGap

    // vertical inset at the top and bottom of the rail
    readonly property int railPad: 16

    // inner padding for cards and panels
    readonly property int padCard: 14
    readonly property int padPanel: 16

    // thickness shared by the slider track and the notification accent bar
    readonly property int barThickness: 4

    // hover latency: quick to wake, slow to close so overshooting toward a
    // modal does not collapse the rail
    readonly property int enterDelay: 120
    readonly property int exitDelay: 400

    readonly property int morphDuration: 340
    readonly property int fadeDuration: 200

    // Delay added per position when a panel's contents reveal sequentially.
    // Well under fadeDuration so the fades overlap heavily and the whole set
    // lands quickly, rather than reading as one item at a time.
    readonly property int staggerStep: 30

    // how long after the panel starts fading before the first card follows;
    // less than fadeDuration so the two overlap instead of queueing
    readonly property int staggerLead: 90

    // how long a toast lingers when the app does not ask for a specific timeout
    readonly property int toastTimeout: 10000

    // meter sampling: tighter while the rail is out, relaxed when it is not
    readonly property int meterIntervalActive: 500
    readonly property int meterInterval: 2000

    // workspace focus travel. Symmetric easing so the shrinking and growing
    // marks mirror each other exactly; InOutQuad is its own reverse.
    readonly property int focusDuration: 260

    // Workspace mark geometry. Heights are identical in both forms so the
    // column never moves vertically on expand; only width changes.
    readonly property int wsFocusedLength: 30
    readonly property int wsOccupiedLength: 12
    readonly property int wsEmptyLength: 12

    // width of a mark in the rail; collapsed it is the sliver width
    readonly property int wsWidth: 12
}
