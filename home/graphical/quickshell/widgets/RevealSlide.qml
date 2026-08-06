import QtQuick
import ".."

// Fade and slide for one row of a panel that reveals its contents in sequence.
//
// Attached to whatever it animates rather than wrapping it, so a row keeps
// whatever layout it already had: it drives the target's opacity and x offset
// directly.
//
// Rows start one stagger step behind the one above, well inside the fade's own
// duration so the whole set overlaps heavily and lands quickly rather than
// arriving one at a time.
Item {
    id: root

    required property Item target

    // position in the sequence, counted from the top
    required property int index

    // true while the panel is up; the reveal follows it
    required property bool shown

    // Which way the row travels in from. Rows come from the edge the panel
    // opened from, so they arrive alongside it rather than against it.
    property bool fromRight: false

    // how far the row starts from its resting place
    property real distance: 12

    visible: false

    // Driven rather than bound: an animation writes to these, and a binding
    // would be destroyed by the first write.
    Component.onCompleted: {
        target.opacity = shown ? 1 : 0;
        target.x = 0;
        if (shown)
            reveal.restart();
    }

    onShownChanged: {
        if (shown)
            reveal.restart();
        else
            dismiss.restart();
    }

    SequentialAnimation {
        id: reveal

        PauseAnimation {
            duration: Theme.staggerLead + root.index * Theme.staggerStep
        }

        // Both at once: the row fades up as it settles, rather than sliding
        // into place and then appearing.
        ParallelAnimation {
            NumberAnimation {
                target: root.target
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.fadeDuration
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root.target
                property: "x"
                from: root.fromRight ? root.distance : -root.distance
                to: 0
                duration: Theme.morphDuration
                easing.type: Easing.OutQuint
            }
        }
    }

    // Closing is not staggered: the rows go together with the panel so
    // dismissal stays crisp, and only the opacity moves so nothing is caught
    // mid travel.
    NumberAnimation {
        id: dismiss

        target: root.target
        property: "opacity"
        to: 0
        duration: Theme.fadeDuration
    }
}
