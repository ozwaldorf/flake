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
    //
    // Checked by rendering rather than by looking them up: a codepoint can be
    // in the cmap and still map to an empty glyph, which draws as the notdef
    // box. The tell is the advance width, which comes out narrower than any
    // real icon's.
    readonly property string iconFont: "FiraCode Nerd Font"
    readonly property int iconSize: 15
    readonly property string iconClose: String.fromCodePoint(0xf467)
    readonly property string iconCpu: String.fromCodePoint(0xf4bc)
    readonly property string iconMemory: String.fromCodePoint(0xefc5)
    readonly property string iconNetwork: String.fromCodePoint(0xf06f3)
    readonly property string iconDisk: String.fromCodePoint(0xf02ca)
    readonly property string iconGpu: String.fromCodePoint(0xe266)
    readonly property string iconHost: String.fromCodePoint(0xf313)

    // matches hyprland decoration.rounding
    readonly property int rounding: 10

    // surface fill shared with foot: background 161616 at alpha 0.8, blurred
    // client side via ext-background-effect-v1
    readonly property color surfaceFill: Qt.rgba(base.r, base.g, base.b, 0.8)

    // the same surface lifted under the pointer
    readonly property color surfaceRaised: Qt.tint(surfaceFill, Qt.alpha(text, 0.06))

    // cards inside the panels, a touch tighter than the window rounding
    readonly property int cardRadius: 9

    readonly property int sliver: 6
    readonly property int rail: 44
    readonly property int modalWidth: 340

    // spacing scale; everything in the modals derives from these rather than
    // carrying its own magic numbers
    readonly property int spaceXs: 8
    readonly property int spaceSm: 14
    readonly property int space: 20
    readonly property int spaceLg: 28

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

    // inner padding for cards
    readonly property int padCard: 14

    // thickness shared by the slider track and the notification accent bar
    readonly property int barThickness: 4

    // hover latency: quick to wake, slow to close so overshooting toward a
    // modal does not collapse the rail
    readonly property int enterDelay: 120
    readonly property int exitDelay: 400

    // Every animation's duration is scaled by this, so the whole shell can be
    // slowed down to inspect motion or sped up to cut it short. Hover latency
    // and timeouts are waits, not motion, and are left alone.
    readonly property real motionScale: 1

    function motion(ms) {
        return Math.round(ms * motionScale);
    }

    // shape changes and travel
    readonly property int morphDuration: motion(340)
    readonly property int fadeDuration: motion(200)

    // On the way out: shorter than the way in, and eased in rather than out,
    // so a dismissal gets out of the way instead of lingering at the end.
    readonly property int exitDuration: motion(120)

    // colour changes under the pointer
    readonly property int hoverDuration: motion(160)

    // glyph state changes, like a slash striking through or arcs dimming
    readonly property int glyphDuration: motion(200)

    // A level settling on a new reading. Kept under the fastest sampling
    // interval, so a meter that is read continuously comes to rest between
    // samples rather than being forever mid flight.
    readonly property int levelDuration: motion(400)

    // a level following a tap or a tick, as on the sliders
    readonly property int trackDuration: motion(180)

    // one turn of a busy spinner
    readonly property int spinDuration: motion(900)

    // How long a surface that just resized under a stationary pointer holds
    // off reading an unhover: Qt re-evaluates hover against the new geometry
    // before the pointer has gone anywhere.
    readonly property int settleDelay: morphDuration + 120

    // Delay added per position when a panel's contents reveal sequentially.
    // Well under fadeDuration so the fades overlap heavily and the whole set
    // lands quickly, rather than reading as one item at a time.
    readonly property int staggerStep: motion(30)

    // Past this many steps everything arrives together: a long stack would
    // otherwise keep its last entries waiting well after the first landed.
    readonly property int staggerCap: 8

    // how long after the panel starts fading before the first card follows;
    // less than fadeDuration so the two overlap instead of queueing
    readonly property int staggerLead: motion(90)

    function stagger(index) {
        return Math.max(0, Math.min(index, staggerCap)) * staggerStep;
    }

    // how long a toast lingers when the app does not ask for a specific timeout
    readonly property int toastTimeout: 10000

    // Wallpaper crossfade. An order of magnitude longer than anything in the
    // shell: the panels are answering a pointer and have to keep up with it,
    // while this is ambient and reads better as a drift than a switch.
    readonly property int wallpaperFade: motion(1600)

    // meter sampling: tighter while the rail is out, relaxed when it is not
    readonly property int meterIntervalActive: 500
    readonly property int meterInterval: 2000

    // workspace focus travel. Symmetric easing so the shrinking and growing
    // marks mirror each other exactly; InOutQuad is its own reverse.
    readonly property int focusDuration: motion(260)

    // Workspace mark geometry. Heights are identical in both forms so the
    // column never moves vertically on expand; only width changes.
    readonly property int wsFocusedLength: 30
    readonly property int wsOccupiedLength: 12
    readonly property int wsEmptyLength: 12

    // width of a mark in the rail; collapsed it is the sliver width
    readonly property int wsWidth: 12

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }
}
