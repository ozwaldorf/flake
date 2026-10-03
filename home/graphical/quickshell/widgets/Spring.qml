import QtQuick
import ".."

// Follows `target` with niri's horizontal view spring: critically damped,
// stiffness 800, unit mass, carrying its velocity into a retarget the way niri
// does. Anything that moves alongside the windows when an exclusive zone
// changes runs on this, so the two stay in step.
//
// Solved in closed form from the moment of each retarget rather than
// integrated, so frame pacing does not drift it off niri's curve. The spring
// is linear, so several of these summed behave as one spring retargeted to
// their combined target.
FrameAnimation {
    id: root

    property real target: 0

    // the current position; read this rather than target
    property real value: 0

    readonly property real omega: Math.sqrt(800) / Theme.motionScale

    property real velocity: 0
    property real c1: 0
    property real c2: 0
    property real startedAt: 0

    onTargetChanged: {
        c1 = value - target;
        c2 = velocity + omega * c1;
        startedAt = Date.now();
        restart();
    }

    onTriggered: {
        // wall clock rather than summed frame times: the first frame after a
        // restart reports the whole idle gap as its frame time
        const t = (Date.now() - startedAt) / 1000;
        const decay = Math.exp(-omega * t);
        const offset = (c1 + c2 * t) * decay;
        velocity = (c2 - omega * (c1 + c2 * t)) * decay;
        if (Math.abs(offset) < 0.0001 && Math.abs(velocity) < 0.01) {
            velocity = 0;
            value = target;
            stop();
            return;
        }
        value = target + offset;
    }
}
