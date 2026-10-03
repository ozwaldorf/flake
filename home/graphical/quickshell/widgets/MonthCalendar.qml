pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."

// Today and the month around it, as one well: a greeting and the date set
// large down one side, the month's grid down the other. The rail shows the
// hour and the minute, which answers when it is but never what day; this is
// the rest of that reading.
Rectangle {
    id: root

    // The date side takes a fixed share of the card and the grid the rest,
    // its cells stretched to meet the far edge.
    readonly property real sideWidth: Math.round((width - Theme.padCard * 2) * 0.4)
    readonly property real cellWidth: (width - Theme.padCard * 2 - sideWidth - Theme.spaceSm * 2 - 1) / 7
    readonly property real cellHeight: 26

    // Minute precision keeps the greeting current; nothing else here changes
    // more often than daily.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Today at midnight, taken from the clock so the month rolls over on its
    // own rather than holding whatever day the card was first built on.
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())

    // Six rows always, so the card keeps one height from month to month.
    readonly property int rows: 6

    // Sunday first, as the week is read here.
    readonly property var dayNames: ["S", "M", "T", "W", "T", "F", "S"]

    // the Sunday on or before the first of the month
    readonly property date gridStart: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay());
    }

    // Row holding today, for the band across the current week. Rounded rather
    // than floored, since a DST change leaves the span an hour off whole days.
    readonly property int todayRow: Math.floor(Math.round((today.getTime() - gridStart.getTime()) / 86400000) / 7)

    implicitHeight: grid.implicitHeight + Theme.padCard * 2

    radius: Theme.cardRadius
    color: Theme.wellFill

    Inset {
        target: root
    }

    // Suffix for a day of the month, since the date formatter has no token for
    // one. The teens end in 1, 2 and 3 but are all th.
    function ordinal(day) {
        if (day >= 11 && day <= 13)
            return "th";
        if (day % 10 === 1)
            return "st";
        if (day % 10 === 2)
            return "nd";
        if (day % 10 === 3)
            return "rd";
        return "th";
    }

    readonly property string greeting: clock.hours >= 5 && clock.hours < 12 ? "Good morning" : clock.hours >= 12 && clock.hours < 17 ? "Good afternoon" : "Good evening"

    // Read top to bottom as one sentence: the greeting, the day's name, the
    // day of the month set large, then the month and year. The greeting holds
    // the top and the month the bottom, so the side spans the grid's height.
    Item {
        anchors.left: parent.left
        anchors.leftMargin: Theme.padCard
        width: root.sideWidth
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padCard

        Column {
            id: greeting

            width: parent.width
            spacing: Theme.spaceXs

            Label {
                width: parent.width
                text: root.greeting + " <font color=\"" + Theme.blue + "\">" + Quickshell.env("USER") + "</font>!"
                textFormat: Text.StyledText
                font.pixelSize: 15
                color: Theme.text
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Label {
                width: parent.width
                text: "Today is <font color=\"" + Theme.blue + "\">" + Qt.formatDateTime(root.today, "dddd") + "</font>,"
                textFormat: Text.StyledText
                // shrunk to hold one line, since the day's name varies in length
                font.pixelSize: 13
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 9
                color: Theme.subtext0
            }
        }

        // The month, the day of the month and the year, centred together in
        // the room under the lines above and spaced by their inked height
        // rather than their line boxes, whose leading grows with the font.
        Item {
            id: dateStack

            anchors.top: greeting.bottom
            anchors.bottom: parent.bottom
            width: parent.width

            readonly property real gap: 12
            readonly property real lead: (height - month.height - number.height - year.height - gap * 2) / 2

            Ink {
                id: month

                anchors.horizontalCenter: parent.horizontalCenter
                y: dateStack.lead
                text: Qt.formatDateTime(root.today, "MMMM")
                pixelSize: 15
                color: Theme.subtext0
            }

            Row {
                id: number

                anchors.horizontalCenter: parent.horizontalCenter
                y: month.y + month.height + dateStack.gap
                spacing: 1

                Ink {
                    text: root.today.getDate()
                    pixelSize: 56
                    bold: true
                    color: Theme.text
                }

                Ink {
                    text: root.ordinal(root.today.getDate())
                    pixelSize: 14
                    color: Theme.overlay1
                }
            }

            Ink {
                id: year

                anchors.horizontalCenter: parent.horizontalCenter
                y: number.y + number.height + dateStack.gap
                text: Qt.formatDateTime(root.today, "yyyy")
                pixelSize: 13
                color: Theme.overlay1
            }
        }
    }

    // Text boxed by its figures' height, baseline to the top of a digit, so
    // the space between lines is the space between the ink.
    component Ink: Item {
        property alias text: label.text
        property alias pixelSize: label.font.pixelSize
        property alias color: label.color
        property bool bold: false

        implicitWidth: label.implicitWidth
        implicitHeight: -digit.tightBoundingRect.y

        Label {
            id: label

            y: -(baselineOffset + digit.tightBoundingRect.y)
            font.weight: parent.bold ? Font.Bold : Font.Normal
            figures: true
        }

        TextMetrics {
            id: digit

            font: label.font
            text: "0"
        }
    }

    Rectangle {
        id: divider

        x: Theme.padCard + root.sideWidth + Theme.spaceSm
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.padCard
        width: 1
        color: Qt.alpha(Theme.text, 0.06)
    }

    Column {
        id: grid

        anchors.right: parent.right
        anchors.rightMargin: Theme.padCard
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard
        spacing: 4

        Row {
            Repeater {
                model: root.dayNames

                Label {
                    required property string modelData
                    required property int index

                    width: root.cellWidth
                    height: 16

                    text: modelData
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                    // weekends set back, bracketing the week
                    color: index === 0 || index === 6 ? Theme.overlay0 : Theme.overlay2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            width: root.cellWidth * 7
            height: 1
            color: Qt.alpha(Theme.text, 0.06)
        }

        Item {
            width: root.cellWidth * 7
            height: root.cellHeight * root.rows

            // a soft band across the current week
            Rectangle {
                y: root.todayRow * root.cellHeight
                width: parent.width
                height: root.cellHeight
                radius: height / 2
                color: Qt.alpha(Theme.text, 0.04)
            }

            Grid {
                columns: 7
                rows: root.rows

                Repeater {
                    model: root.rows * 7

                    Item {
                        id: cell

                        required property int index

                        width: root.cellWidth
                        height: root.cellHeight

                        readonly property date date: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                        readonly property bool outside: date.getMonth() !== root.today.getMonth()
                        readonly property bool isToday: date.getTime() === root.today.getTime()
                        readonly property bool past: date.getTime() < root.today.getTime()

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.cellHeight - 4
                            height: width
                            radius: width / 2
                            color: Theme.blue
                            visible: cell.isToday
                        }

                        // Days already gone in the month sit a step back from
                        // those still to come, so the month reads as time spent
                        // and time left.
                        Label {
                            anchors.fill: parent

                            text: cell.date.getDate()
                            font.pixelSize: 11
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                            figures: true
                            color: {
                                if (cell.isToday)
                                    return Theme.crust;
                                if (cell.outside)
                                    return Theme.surface2;
                                if (cell.past)
                                    return Theme.overlay1;
                                return Theme.subtext1;
                            }
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
