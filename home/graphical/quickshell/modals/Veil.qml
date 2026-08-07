import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Fullscreen blur over everything, raised while the session is idle.
//
// The blur is the compositor's: the window declares its whole area as a blur
// region and hyprland ramps both the blur's alpha and its radius with the
// layer's fade, so the veil dissolves in rather than snapping on. Nothing is
// drawn into it beyond that, since the frosting is the entire effect.
PanelWindow {
    id: root

    required property var modelData

    property bool shown: false

    screen: modelData
    color: "transparent"

    // Above every other layer, the bar and its modals included: a veil with the
    // shell drawn on top of it is not a veil.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-veil"

    // Nothing underneath is meant to be reachable while the veil is up. Held
    // unconditionally rather than keyed to shown: the window only exists while
    // it is up, so there is no state in which the grab should be released.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Taken down rather than left transparent: an overlay window that outlives
    // its fade keeps swallowing input over the whole screen.
    visible: shown

    // Ignoring the other layers' zones rather than merely declining one of its
    // own: respecting the bar's reservation insets the veil by the rail's
    // width and leaves a strip of the screen unblurred. A zone cannot be set
    // in this mode, which is why exclusiveZone is not given here.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Every pixel, so no click reaches what is behind the veil. A window with
    // an empty mask is click through, which is the opposite of the intent.
    mask: Region {
        item: body
    }

    Item {
        id: body
        anchors.fill: parent
    }

    // The whole surface. Hyprland clips one blurred texture to this region and
    // fades it with the layer, which is what animates the veil.
    BackgroundEffect.blurRegion: Region {
        item: body
    }
}
