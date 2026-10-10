import QtQuick

// A shadow cast from an edge onto the layer beneath it, darkest along the
// given side. Falls away quickly rather than evenly across its depth: a
// linear ramp is still visibly dark where it ends, which reads as a band
// with an edge rather than a shadow fading out.
Rectangle {
    id: shadow

    // the side it is darkest along: left, right, top or bottom
    required property string side
    property real peak: 0.4

    readonly property bool across: side === "left" || side === "right"

    // darkest at the start of the gradient rather than its end
    readonly property bool fromStart: side === "left" || side === "top"

    width: across ? 18 : parent.width
    height: across ? parent.height : 18

    gradient: Gradient {
        orientation: shadow.across ? Gradient.Horizontal : Gradient.Vertical

        GradientStop {
            position: 0
            color: Qt.alpha("black", shadow.fromStart ? shadow.peak : 0)
        }
        GradientStop {
            position: shadow.fromStart ? 0.35 : 0.65
            color: Qt.alpha("black", shadow.peak * 0.22)
        }
        GradientStop {
            position: 1
            color: Qt.alpha("black", shadow.fromStart ? 0 : shadow.peak)
        }
    }
}
