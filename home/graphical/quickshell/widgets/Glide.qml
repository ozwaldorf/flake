import QtQuick
import ".."

// For values the pointer can turn around mid flight, like the rail opening or
// a card lifting. A change arriving part way carries on from the current speed
// and eases into the new direction, rather than restarting a curve from rest
// and jolting.
SmoothedAnimation {
    velocity: -1
    duration: Theme.morphDuration
}
