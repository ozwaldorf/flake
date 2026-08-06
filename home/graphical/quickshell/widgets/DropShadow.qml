import QtQuick
import QtQuick.Effects
import ".."

// Shadow cast by a rounded rectangle, drawn behind whatever it is given.
//
// Its own item rather than a layer effect on the surface: a layer renders the
// surface into a texture to blur it, which for a translucent card over a blur
// region means compositing it twice and losing the frosting behind it. This
// only ever needs the shape, which is known.
Item {
    id: root

    // the surface casting it; only its size and rounding are read
    required property Item target

    // how far it falls and how soft it is, both eased so a card lifting under
    // the pointer settles rather than snapping
    property real elevation: 6
    property real strength: 0.35

    Behavior on elevation {
        NumberAnimation {
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuad
        }
    }

    Behavior on strength {
        NumberAnimation {
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuad
        }
    }

    // How far the shadow is pushed down as a fraction of the spread, so the
    // light reads as coming from above. Zero spreads it evenly, for something
    // round enough that a drop below it reads as lopsided rather than lit.
    property real sink: 0.4

    anchors.fill: target
    anchors.margins: -elevation

    z: -1

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.elevation
        anchors.topMargin: root.elevation * (1 - root.sink)
        anchors.bottomMargin: root.elevation * (1 + root.sink)

        radius: root.target.radius ?? 9
        color: "black"

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 32
            blur: 1
        }

        opacity: root.strength
    }
}
