import QtQuick
import ".."

Row {
    id: root

    required property string label
    property real value: 0
    property bool muted: false

    signal moved(real value)

    readonly property int labelWidth: 74
    readonly property int valueWidth: 36
    readonly property real clamped: Math.max(0, Math.min(1, value))

    spacing: Theme.spaceSm

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        text: root.label
        font.family: Theme.font
        font.pixelSize: 10
        color: root.muted ? Theme.surface2 : Theme.overlay1
        elide: Text.ElideRight
    }

    // taller than the track so the hit target is not a 4px sliver
    Item {
        id: hit

        anchors.verticalCenter: parent.verticalCenter
        width: root.width - root.labelWidth - root.valueWidth - root.spacing * 2
        height: 22

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.barThickness
            radius: 2
            color: Theme.surface1

            Rectangle {
                width: parent.width * root.clamped
                height: parent.height
                radius: 2
                color: root.muted ? Theme.surface2 : Theme.blue

                Behavior on width {
                    enabled: !drag.active
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuint
                    }
                }
            }
        }

        Rectangle {
            x: track.width * root.clamped - width / 2
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 11
            implicitHeight: 11
            radius: 5.5
            color: Theme.text

            Behavior on x {
                enabled: !drag.active
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutQuint
                }
            }
        }

        DragHandler {
            id: drag

            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onCentroidChanged: {
                if (active)
                    root.moved(Math.max(0, Math.min(1, centroid.position.x / track.width)));
            }
        }

        TapHandler {
            onTapped: eventPoint => root.moved(Math.max(0, Math.min(1, eventPoint.position.x / track.width)))
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value * 100) + "%"
        font.family: Theme.font
        font.pixelSize: 10
        font.features: {
            "tnum": 1
        }
        color: Theme.overlay1
    }
}
