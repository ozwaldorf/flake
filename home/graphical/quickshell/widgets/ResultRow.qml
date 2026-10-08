import QtQuick
import Quickshell
import ".."

// One result in a searchable drawer: an icon, a title over a quieter line
// under it, and a hint against the far edge. Lit while it is the one the
// keyboard is on; the pointer moves that selection rather than lighting a
// second row beside it.
Rectangle {
    id: root

    property bool current: false

    // an icon theme name or path, with a glyph from the icon font standing in
    // when there is none or the theme lacks it
    property string icon: ""
    readonly property string iconSource: icon.startsWith("/") ? `file://${icon}` : icon !== "" ? Quickshell.iconPath(icon, true) : ""
    property string glyph: ""
    property color glyphColor: Theme.overlay1

    property string title: ""
    property string detail: ""
    property string hint: ""

    // what stands in the icon's place instead, as a thumbnail
    property alias leading: slot.data
    property real leadSize: 28

    // a track along the foot while work behind the row is under way, filled
    // to progress, or swept while progress is -1 and there is no measure
    property bool loading: false
    property real progress: -1

    readonly property bool hovered: hover.hovered

    signal tapped
    signal entered

    implicitWidth: ListView.view ? ListView.view.width : 0
    implicitHeight: 44
    radius: 6

    // alpha zero rather than "transparent", which is transparent black and
    // drags the fade through black at both ends
    color: current ? Theme.surface0 : Qt.alpha(Theme.surface0, 0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.hoverDuration
        }
    }

    Item {
        id: slot

        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        width: root.leadSize
        height: root.leadSize

        Image {
            readonly property int px: Math.ceil(width * Screen.devicePixelRatio)

            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: px
            sourceSize.height: px
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconSource === "" && root.glyph !== ""
            text: root.glyph
            font.family: Theme.iconFont
            font.pixelSize: 18
            color: root.glyphColor
        }
    }

    Column {
        anchors.left: slot.right
        anchors.leftMargin: Theme.spaceSm
        anchors.right: hintLabel.left
        anchors.rightMargin: Theme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Label {
            width: parent.width
            text: root.title
            font.pixelSize: 12
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.detail
            color: Theme.overlay0
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    Label {
        id: hintLabel

        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: root.current ? Theme.overlay1 : Qt.alpha(Theme.overlay1, 0)

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
            }
        }
    }

    Item {
        anchors.left: slot.right
        anchors.leftMargin: Theme.spaceSm
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        height: 2
        visible: root.loading
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.alpha(Theme.surface2, 0.55)
        }

        Rectangle {
            id: fill

            readonly property bool measured: root.progress >= 0

            // The sweep runs over a fraction rather than over pixels, so it
            // follows the track as it is laid out instead of the zero width
            // a fresh row starts at
            property real sweep: 0

            x: measured ? 0 : sweep * (parent.width + width) - width
            width: measured ? parent.width * Theme.clamp01(root.progress) : parent.width / 4
            height: parent.height
            radius: height / 2
            color: Theme.blue

            Behavior on width {
                enabled: fill.measured
                NumberAnimation {
                    duration: Theme.trackDuration
                }
            }

            NumberAnimation on sweep {
                running: root.loading && !fill.measured
                from: 0
                to: 1
                duration: Theme.spinDuration * 1.5
                loops: Animation.Infinite
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered)
                root.entered();
        }
    }

    TapHandler {
        onTapped: root.tapped()
    }
}
