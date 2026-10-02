import QtQuick
import ".."

// Text in the shell's face. Figures that update in place set tabular so the
// digits hold their width instead of jittering as they count.
Text {
    property bool figures: false

    font.family: Theme.font
    font.pixelSize: 10
    font.features: figures ? ({
            "tnum": 1
        }) : ({})
    color: Theme.text
}
