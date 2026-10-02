import QtQuick
import ".."

// An opacity change, eased out so it lands softly rather than stopping dead.
NumberAnimation {
    duration: Theme.fadeDuration
    easing.type: Easing.OutQuad
}
