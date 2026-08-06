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

    // Mirrored with the rail: a row comes in from the rail's own side, so on
    // the right hand screen it travels leftward rather than rightward.
    property bool fromRight: false

    // how far the row starts from its resting place
    property real distance: 12

    // where the row settles, for anything not resting at its parent's origin
    property real restX: 0

    visible: false

    // Driven rather than bound: an animation writes to these, and a binding
    // would be destroyed by the first write.
    Component.onCompleted: {
        target.opacity = shown ? 1 : 0;
        target.x = restX;
        if (shown)
            reveal.restart();
    }

    // Followed while nothing is animating, since a resting place that depends
    // on the target's own size is not known when it is first placed: a chip
    // aligned to the far edge of its stack is put at the wrong end until its
    // width resolves, and a one shot write never revisits it.
    onRestXChanged: {
        if (!reveal.running && !dismiss.running)
            target.x = restX;
    }

    // A reveal opens with a pause of up to its whole stagger before anything
    // moves, so a pointer crossing the hover boundary twice inside that window
    // cancels it and re-queues the pause: the row never fades in at all. The
    // one furthest down the sequence waits longest and is likeliest to be
    // caught, which shows as only the first of them arriving.
    //
    // A reveal already under way is left to finish rather than restarted, and
    // a dismissal waits for it: whatever the pointer did in the meantime, the
    // row ends up wherever shown last said it should be.
    onShownChanged: {
        if (shown) {
            if (!reveal.running)
                reveal.restart();
        } else if (reveal.running) {
            pendingDismiss = true;
        } else {
            dismiss.restart();
        }
    }

    // set when a dismissal arrives mid reveal, run once that reveal is done
    property bool pendingDismiss: false

    SequentialAnimation {
        id: reveal

        onFinished: {
            // the pointer left while this was still coming in, so see it out
            // again now rather than having cut the arrival short
            if (root.pendingDismiss && !root.shown) {
                root.pendingDismiss = false;
                dismiss.restart();
            } else {
                root.pendingDismiss = false;
            }
        }

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
                from: root.restX + (root.fromRight ? root.distance : -root.distance)
                to: root.restX
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
