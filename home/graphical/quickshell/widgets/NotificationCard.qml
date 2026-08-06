pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import ".."
import "../services"

// One card, rendered identically whether it appears as a transient toast or as
// an entry in the control centre. The only difference is where it is loaded.
Rectangle {
    id: root

    required property var entry

    // stripe sits on the edge facing the rail
    property bool anchorRight: false

    // Raised while this card or one of its children has the pointer, so a
    // containing panel can tell the pointer has not left it.
    //
    // The card counts its own outstanding raises so it can release them all on
    // destruction: dismissing a hovered card would otherwise leave the panel's
    // counter permanently incremented and the modal stuck open.
    signal childHoverChanged(bool hovered)

    property int hoverRaises: 0

    function raiseHover(on) {
        hoverRaises += on ? 1 : -1;
        childHoverChanged(on);
    }

    Component.onDestruction: {
        while (hoverRaises > 0) {
            hoverRaises--;
            childHoverChanged(false);
        }
    }

    readonly property bool critical: entry.urgency === NotificationUrgency.Critical

    // Any outstanding raise means the pointer is over the card or one of its
    // controls. Reading cardHover alone would drop while the close affordance
    // has the pointer, making it vanish as you reach for it.
    readonly property bool hovered: hoverRaises > 0

    implicitHeight: content.implicitHeight + Theme.padCard * 2
    radius: Theme.rounding
    // lifts toward surface0 on hover, keeping the surface alpha rather than
    // going through Qt.lighter, which distorts translucent colours
    color: Qt.rgba(hovered ? Theme.surface0.r : Theme.base.r, hovered ? Theme.surface0.g : Theme.base.g, hovered ? Theme.surface0.b : Theme.base.b, 0.8)
    border.width: 1
    border.color: hovered ? Theme.surface2 : Theme.surface1

    Behavior on color {
        ColorAnimation {
            duration: Theme.fadeDuration
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.fadeDuration
        }
    }

    // urgency stripe, clipped so it follows the card radius rather than sitting
    // outside it
    Item {
        anchors.left: root.anchorRight ? undefined : parent.left
        anchors.right: root.anchorRight ? parent.right : undefined
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.barThickness
        clip: true

        Rectangle {
            width: root.width
            height: root.height
            x: root.anchorRight ? -root.width + Theme.barThickness : 0
            radius: root.radius
            color: root.critical ? Theme.red : root.entry.urgency === NotificationUrgency.Low ? Theme.surface2 : Theme.yellow
        }
    }

    Column {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.padCard
        // extra inset on whichever side carries the stripe
        anchors.leftMargin: root.anchorRight ? Theme.padCard : Theme.padCard + Theme.barThickness
        anchors.rightMargin: root.anchorRight ? Theme.padCard + Theme.barThickness : Theme.padCard
        spacing: Theme.spaceXs

        Text {
            // clears the close affordance, which overlays the top right
            width: parent.width - closeButton.width - Theme.spaceXs
            text: root.entry.appName.toUpperCase()
            font.family: Theme.font
            font.pixelSize: 9
            font.letterSpacing: 0.9
            color: Theme.overlay0
            elide: Text.ElideRight
        }

        Text {
            width: parent.width - closeButton.width - Theme.spaceXs
            text: root.entry.summary
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.text
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }

        Text {
            width: parent.width
            text: root.entry.body
            font.family: Theme.font
            font.pixelSize: 11
            color: Theme.overlay2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 4
            visible: text.length > 0
        }

        // Actions hug the same edge as the urgency stripe, so on a right
        // anchored bar they sit right rather than reading against the card.
        Row {
            width: parent.width
            spacing: Theme.spaceXs
            topPadding: 3
            layoutDirection: root.anchorRight ? Qt.RightToLeft : Qt.LeftToRight
            visible: root.entry.notification?.actions?.length > 0

            Repeater {
                model: root.entry.notification?.actions ?? []

                Rectangle {
                    id: actionButton

                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + Theme.spaceLg
                    implicitHeight: 26
                    radius: 6
                    color: Theme.surface1
                    border.width: 1
                    border.color: actionHover.hovered ? Theme.blue : Theme.surface2

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: actionButton.modelData.text
                        font.family: Theme.font
                        font.pixelSize: 10
                        color: actionHover.hovered ? Theme.blue : Theme.subtext0
                    }

                    HoverHandler {
                        id: actionHover
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: root.raiseHover(hovered)
                    }

                    TapHandler {
                        onTapped: actionButton.modelData.invoke()
                    }
                }
            }
        }
    }

    // Purely informational: a hint that clicking the card clears it. No hover
    // state or handlers of its own, so the whole card stays one target. Always
    // on the right regardless of which edge the accent bar sits on.
    Text {
        id: closeButton

        anchors.right: parent.right
        anchors.top: parent.top
        // matches the content column's inset on this side, which carries the
        // extra stripe clearance when the bar is anchored right
        anchors.rightMargin: root.anchorRight ? Theme.padCard + Theme.barThickness : Theme.padCard
        anchors.topMargin: Theme.padCard

        text: Theme.iconClose
        font.family: Theme.iconFont
        font.pixelSize: 11
        color: Theme.overlay1

        opacity: root.hovered ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fadeDuration
            }
        }
    }

    // Declared last so it sits above the content and is not shadowed by the
    // action buttons' own handlers; hover is passive, so their taps still land.
    HoverHandler {
        id: cardHover

        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.raiseHover(hovered)
    }

    // lifts a little under the pointer, so the card reads as coming forward
    // rather than only changing colour
    DropShadow {
        target: root
        elevation: cardHover.hovered ? 9 : 6
        strength: cardHover.hovered ? 0.45 : 0.35
    }
}
