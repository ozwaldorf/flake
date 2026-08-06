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

    // Sits directly behind what casts it, spread evenly on every side rather
    // than dropped below: the surfaces are lifted off the background, not lit
    // from one direction, and an even shadow is what reads as height.
    anchors.fill: target
    anchors.margins: -elevation

    z: -1

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.elevation

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
