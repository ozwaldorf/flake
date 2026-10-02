pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import ".."

// The month around today, opened by hovering the clock. The rail shows the hour
// and the minute, which answers when it is but never what day; this is the rest
// of that reading.
//
// One card rather than a row of them: a month is a single grid, and the date
// above it is its heading rather than a separate fact.
TipWindow {
    id: root

    // Seven columns of two digits with air around them, which is what sets the
    // width; the card is sized from the grid rather than the grid fitted to a
    // width picked first.
    readonly property real cellSize: 30

    readonly property real cardWidth: cellSize * 7 + Theme.padCard * 2

    implicitWidth: Theme.rail + Theme.spaceXs + cardWidth + shadowRoom

    // Day precision: nothing here changes between minutes, and a clock ticking
    // faster than the thing it drives only wakes the process for no redraw.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Today at midnight, which is what the grid is built around and what a cell
    // compares itself against. Taken from the clock rather than read fresh, so
    // the month rolls over on its own at midnight instead of holding whatever
    // day the card was first built on.
    readonly property date today: new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())

    // Suffix for a day of the month, since the date formatter has no token for
    // one. The teens are the exception that has to be taken first: they end in
    // the digits that would otherwise read st, nd and rd, but are all th.
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

    // Six rows of seven always, rather than however many the month happens to
    // need: a grid that changes height between months moves the card under a
    // stationary pointer, and the leading and trailing days fill the slack.
    readonly property int rows: 6

    // Sunday first, as the week is read here.
    readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // The Sunday on or before the first of the month, which is where the grid
    // starts. Offsetting a date by days rather than assembling one from parts
    // lets the Date itself carry the month and year backward.
    readonly property date gridStart: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        // getDay is already Sunday based, so it is the offset as it stands
        return new Date(first.getFullYear(), first.getMonth(), 1 - first.getDay());
    }

    Rectangle {
        id: card

        x: root.contentX
        y: root.placeY(height)

        width: root.cardWidth
        implicitHeight: body.implicitHeight + Theme.padCard * 2
        height: implicitHeight

        radius: Theme.rounding
        color: Theme.surfaceFill
        opacity: 0

        RevealSlide {
            target: card
            index: 0
            shown: root.shown
            fromRight: root.anchorRight
            restX: root.contentX
        }

        CardBlur {
            target: card
            host: root
        }

        DropShadow {
            target: card
        }

        Column {
            id: body

            anchors.fill: parent
            anchors.margins: Theme.padCard
            spacing: Theme.spaceXs

            // The date in full: the grid says which month, so the heading's job
            // is to say which day of it, which is the one thing the rail's
            // digits leave out. Written the way it is said rather than the way
            // it sorts, ordinal and all.
            Text {
                width: parent.width

                text: Qt.formatDateTime(root.today, "dddd, MMMM ") + root.today.getDate() + root.ordinal(root.today.getDate()) + Qt.formatDateTime(root.today, ", yyyy")
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.text
                elide: Text.ElideRight
            }

            // Separates the heading from the grid, which are read as two things
            // rather than one block of figures.
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surface0
            }

            Row {
                Repeater {
                    model: root.dayNames

                    Text {
                        required property string modelData
                        required property int index

                        width: root.cellSize
                        height: 20

                        text: modelData
                        font.family: Theme.font
                        font.pixelSize: 9
                        // The weekend, marked in the header rather than in the
                        // cells: a whole column tinted would fight the mark on
                        // today, and the label is enough to find it by. It
                        // brackets the week now rather than closing it.
                        color: index === 0 || index === 6 ? Theme.overlay0 : Theme.overlay2
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Grid {
                columns: 7
                rows: root.rows

                Repeater {
                    model: root.rows * 7

                    Item {
                        id: cell

                        required property int index

                        width: root.cellSize
                        height: root.cellSize

                        readonly property date date: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)

                        // Leading and trailing days are shown rather than left
                        // blank, so the weeks either side of the month are
                        // still readable, but dimmed well back: they are
                        // context for the month, not part of it.
                        readonly property bool outside: date.getMonth() !== root.today.getMonth()

                        readonly property bool isToday: date.getTime() === root.today.getTime()

                        // The one cell that is looked for, so it is the one
                        // thing here carrying a fill rather than only a colour.
                        Rectangle {
                            anchors.centerIn: parent
                            width: root.cellSize - 6
                            height: root.cellSize - 6
                            radius: 6
                            color: Theme.blue
                            visible: cell.isToday
                        }

                        Text {
                            anchors.fill: parent

                            text: cell.date.getDate()
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.features: {
                                "tnum": 1
                            }
                            color: {
                                if (cell.isToday)
                                    return Theme.crust;
                                if (cell.outside)
                                    return Theme.surface2;
                                return Theme.subtext0;
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
