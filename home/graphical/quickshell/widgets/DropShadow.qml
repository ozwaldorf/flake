import QtQuick
import QtQuick.Effects
import ".."

// Shadow cast by a rounded rectangle, drawn behind whatever it is given.
//
// Its own item rather than a layer effect on the surface: a layer renders the
// surface into a texture to blur it, which for a translucent card over a blur
// region means compositing it twice and losing the frosting behind it. This
// only ever needs the shape, which is known, so it is drawn analytically with
// no offscreen pass at all.
RectangularShadow {
    id: root

    // the surface casting it; only its size and rounding are read
    required property Item target

    // How far it falls and how soft it is, glided so a card lifting under the
    // pointer settles rather than snapping, and a pointer that crosses it on
    // the way somewhere else turns the lift around without a jolt.
    property real elevation: 6
    property real strength: 0.35

    Behavior on elevation {
        Glide {
            duration: Theme.fadeDuration
        }
    }

    Behavior on strength {
        Glide {
            duration: Theme.fadeDuration
        }
    }

    // Sits directly behind what casts it, spread evenly on every side rather
    // than dropped below: the surfaces are lifted off the background, not lit
    // from one direction, and an even shadow is what reads as height.
    anchors.fill: target
    z: -1

    radius: (target as Rectangle)?.radius ?? Theme.cardRadius
    blur: elevation * 5
    color: Qt.alpha("black", strength)
}
