import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

// The background layer for one screen.
//
// Two images are kept alive at once and blended in a shader, which also applies
// the palette grade. Both happen in the same pass so the fade never shows an
// ungraded frame, and so the whole thing costs one fullscreen draw while it is
// moving and nothing at all once it has settled.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData

    // Under every other layer, including the bar's own. Opaque black rather
    // than transparent: this is the bottom of the stack, so there is nothing
    // behind it to show through, and declaring it opaque lets the compositor
    // skip what it covers.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "quickshell-wallpaper"
    color: "black"

    // The bar reserves an edge, and honouring that reservation would inset the
    // wallpaper and leave a strip of bare compositor along it.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Nothing here is interactive, and a background that swallowed clicks would
    // take them from the desktop underneath.
    mask: Region {}

    // Which of the two slots is showing. Swapped only once the other one has
    // finished decoding: swapping on assignment would point the shader at an
    // empty slot for as long as the load takes, which reads as a flash of
    // black before the fade.
    property bool showingB: false
    readonly property Image showing: showingB ? imageB : imageA
    readonly property Image loading: showingB ? imageA : imageB

    // Driven to 1 to fade the incoming slot in. Held at whichever end matches
    // the current slot so a reload does not restart a completed fade.
    property real progress: 0

    // Decoded at the size actually drawn rather than the file's own. A photo
    // off Commons is several times the size of any output, and decoding it in
    // full would cost tens of megabytes per screen for detail that is then
    // scaled away.
    readonly property size decodeSize: Qt.size(root.width * root.screen.devicePixelRatio, root.height * root.screen.devicePixelRatio)

    function apply(path) {
        if (path === "" || !Wallpaper.clutReady)
            return;

        const url = Qt.resolvedUrl(path);

        // Already up, or already on its way in: a reload, or the same file
        // picked twice.
        if (showing.source == url || loading.source == url)
            return;

        // Only loaded here. The swap waits for it to decode, in onSlotLoaded.
        loading.source = path;
    }

    // Called by whichever slot finished decoding. The one that is not showing
    // is the new image, so the swap happens here rather than on assignment.
    function onSlotLoaded(slot) {
        // Status is checked rather than assumed: this is also called when the
        // table finishes, where the slot may still be decoding.
        if (slot !== loading || slot.status !== Image.Ready || clut.status !== Image.Ready)
            return;

        // Read before the swap, while this still refers to the outgoing image.
        const hadPrevious = showing.source != "";

        showingB = !showingB;

        // Nothing to fade from on the first image of the session, so it is put
        // up whole rather than dissolving in out of an empty slot.
        if (!hadPrevious) {
            progress = showingB ? 1 : 0;
            return;
        }

        fade.restart();
    }

    Connections {
        target: Wallpaper

        function onCurrentChanged() {
            root.apply(Wallpaper.current);
        }

        // The first image can arrive before the CLUT is ready, in which case
        // apply() declined it and it has to be picked up here instead.
        function onClutReadyChanged() {
            root.apply(Wallpaper.current);
        }
    }

    Component.onCompleted: apply(Wallpaper.current)

    // Both slots are hidden: they exist to be sampled by the shader, and
    // drawing them directly would show the ungraded original underneath it.
    Image {
        id: imageA
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize: root.decodeSize
        onStatusChanged: if (status === Image.Ready) root.onSlotLoaded(this)
    }

    Image {
        id: imageB
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize: root.decodeSize
        onStatusChanged: if (status === Image.Ready) root.onSlotLoaded(this)
    }

    // Nearest filtered: the shader interpolates between CLUT entries itself,
    // and letting the sampler do it as well blends across entries that are not
    // neighbours in the color cube wherever a row of the table wraps.
    Image {
        id: clut
        source: Wallpaper.clutReady ? Wallpaper.clutPath : ""
        visible: false
        cache: false
        smooth: false
        asynchronous: true

        // An image that decoded before the table did was turned away, since
        // there was nothing to grade it through yet. Picked up here once there
        // is, which is the ordering on a cold start: the fetch is a network
        // round trip and the table is generated locally, but only after it.
        onStatusChanged: if (status === Image.Ready) root.onSlotLoaded(root.loading)
    }

    // Whether there is anything to draw at all. Only the showing slot is
    // required: the other one holds the previous image, or the next one part
    // way through loading, and gating on it would blank the screen for the
    // length of every load.
    readonly property bool ready: showing.status === Image.Ready && clut.status === Image.Ready

    NumberAnimation {
        id: fade

        target: root
        property: "progress"
        to: root.showingB ? 1 : 0
        duration: Theme.wallpaperFade
        easing.type: Easing.InOutQuad

        onFinished: {
            // Released once it is no longer being sampled: two full screen
            // textures per monitor is worth holding during a fade and not
            // after one. This is the slot that was faded away from, which the
            // swap has already made the loading one.
            root.loading.source = "";
        }
    }

    ShaderEffect {
        anchors.fill: parent

        // Held back until every input is loaded. The effect samples all three
        // unconditionally, and an unset one reads as black.
        visible: root.ready

        property Image fromTex: imageA
        property Image toTex: imageB
        property Image clut: clut

        // The shader blends from A to B, so a fade that is running the other
        // way is expressed by inverting it here rather than by swapping which
        // slot is which.
        property real progress: root.progress
        property real level: Wallpaper.clutLevel

        fragmentShader: Wallpaper.shaderDir + "wallpaper.frag.qsb"
    }
}
