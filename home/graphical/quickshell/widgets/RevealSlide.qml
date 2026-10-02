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

    // Whether leaving is staggered like arriving. Off by default: the rows go
    // together with the panel so its dismissal stays crisp, and a sequence
    // there would only hold the panel on screen after it was asked to close.
    // A set being cleared while the panel stays up is the other case, where
    // the sequence is the point.
    property bool staggerExit: false

    // Counted the other way to the reveal, so a set clears from the end it
    // built toward rather than unwinding in the order it arrived.
    property int exitIndex: index

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
        if (!reveal.running && !resume.running && !dismiss.running)
            target.x = restX;
    }

    // Every change turns the row around from wherever it is. Leaving starts at
    // once from the current opacity, so a panel closed mid reveal does not
    // hold its window open on rows still finishing their entrance. Coming back
    // to a row that is partly drawn picks it straight back up rather than
    // dropping it to nothing and queuing behind the stagger again.
    onShownChanged: {
        reveal.stop();
        resume.stop();
        dismiss.stop();

        if (!shown)
            dismiss.restart();
        else if (target.opacity > 0)
            resume.restart();
        else
            reveal.restart();
    }

    SequentialAnimation {
        id: reveal

        PauseAnimation {
            duration: Theme.staggerLead + Theme.stagger(root.index)
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

    // back from part way out, with no stagger: the row is already on screen
    ParallelAnimation {
        id: resume

        NumberAnimation {
            target: root.target
            property: "opacity"
            to: 1
            duration: Theme.fadeDuration
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root.target
            property: "x"
            to: root.restX
            duration: Theme.morphDuration
            easing.type: Easing.OutQuint
        }
    }

    SequentialAnimation {
        id: dismiss

        PauseAnimation {
            duration: root.staggerExit ? Theme.stagger(root.exitIndex) : 0
        }

        // Opacity alone, so nothing is caught mid travel; eased in so it gets
        // out of the way rather than lingering at the end.
        NumberAnimation {
            target: root.target
            property: "opacity"
            to: 0
            duration: Theme.exitDuration
            easing.type: Easing.InQuad
        }
    }
}
