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

    // Which of the two slots is showing. Swapped per change so the outgoing
    // image stays loaded for the length of the fade instead of being replaced
    // underneath it.
    property bool showingB: false
    readonly property Image incoming: showingB ? imageB : imageA
    readonly property Image outgoing: showingB ? imageA : imageB

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

        // Already showing it: a reload, or the same file picked twice.
        if (incoming.source == Qt.resolvedUrl(path))
            return;

        outgoing.source = path;
        showingB = !showingB;
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
    }

    Image {
        id: imageB
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize: root.decodeSize
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
    }

    // The fade only starts once the new image has actually decoded. Starting it
    // on assignment would fade towards a slot that is still empty, which reads
    // as a flash of black partway through.
    readonly property bool ready: incoming.status === Image.Ready && clut.status === Image.Ready

    onReadyChanged: {
        if (!ready)
            return;

        // Nothing to fade from on the first image of the session, so it is put
        // up whole rather than dissolving in out of an empty slot.
        if (outgoing.source == "") {
            progress = showingB ? 1 : 0;
            return;
        }

        fade.restart();
    }

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
            // after one.
            root.outgoing.source = "";
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
