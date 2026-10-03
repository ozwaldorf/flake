pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Today and the month around it, as one well: the date in words down one side,
// the month's grid down the other. The rail shows the hour and the minute,
// which answers when it is but never what day; this is the rest of that
// reading.
Rectangle {
    id: root

    // two digits with air around them, a little wider than tall so the grid
    // sits as a block beside the date rather than a tall column
    readonly property real cellWidth: 28
    readonly property real cellHeight: 24

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

    implicitHeight: grid.implicitHeight + Theme.padCard * 2

    // a well in the drawer, like everything else behind the desktop
    radius: Theme.cardRadius
    color: Theme.wellFill

    Inset {
        target: root
    }

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

    // A fortune for the hour: drawn once and kept against the date and hour,
    // so the drawer shows the same one however often it opens, and a new one
    // on the hour. Kept to the short, attributed kinds, and short enough to
    // sit beside the month in a few lines.
    property var quote: ["", ""]

    // drawing again on the hour, which the minute clock passes through
    readonly property int hour: clock.hours
    onHourChanged: fortune.draw(false)

    // a fresh one now, kept for the rest of the hour in place of the last
    function redraw() {
        fortune.draw(true);
    }

    Process {
        id: fortune

        // whether to draw a new one even if this hour already has one
        property bool force: false

        function draw(again) {
            force = again;
            running = true;
        }

        running: true
        command: ["sh", "-c", "f=\"$1\"; d=$(date +%F-%H); mkdir -p \"$(dirname \"$f\")\"; if [ \"$2\" = 1 ] || [ \"$(head -1 \"$f\" 2>/dev/null)\" != \"$d\" ]; then { echo \"$d\"; fortune -s -n 80 wisdom literature people humorists science pratchett; } > \"$f\"; fi; tail -n +2 \"$f\"", "sh", Quickshell.statePath("fortune"), force ? "1" : "0"]

        stdout: StdioCollector {
            onStreamFinished: {
                // The attribution, when there is one, is the last line after
                // a double dash; the rest is wrapped for a terminal, so its
                // line breaks are folded back into spaces.
                const raw = text.trim();
                const m = /\n\s*--\s*(.+)$/.exec(raw);
                const body = (m ? raw.slice(0, m.index) : raw).replace(/\s+/g, " ").trim();
                root.quote = [body, m ? m[1].trim() : ""];
            }
        }
    }

    // Today in words, the one thing the rail's digits leave out, and a line
    // to take into it, changing with the date.
    Column {
        anchors.left: parent.left
        anchors.leftMargin: Theme.padCard
        anchors.right: grid.left
        anchors.rightMargin: Theme.space
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard
        spacing: Theme.spaceSm

        // Two set lines rather than one wrapped run: the day's name belongs
        // with "Today is", and a wrap that pushed it down a line read as a
        // list rather than a sentence.
        Column {
            width: parent.width
            spacing: 3

            Text {
                width: parent.width
                text: "Today is <font color=\"" + Theme.blue + "\">" + Qt.formatDateTime(root.today, "dddd") + "</font>,"
                textFormat: Text.StyledText
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: Qt.formatDateTime(root.today, "MMMM ") + root.today.getDate() + root.ordinal(root.today.getDate()) + Qt.formatDateTime(root.today, " yyyy")
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        // the rule between the date and the quote, and after it a way to draw
        // another
        Item {
            width: parent.width
            height: reload.height

            Rectangle {
                id: rule

                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 1
                color: Theme.surface1
            }

            Text {
                id: reload

                anchors.left: rule.right
                anchors.leftMargin: Theme.spaceSm
                text: String.fromCodePoint(0xf021)
                font.family: Theme.iconFont
                font.pixelSize: 11
                color: reloadArea.containsMouse ? Theme.text : Theme.overlay0

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }

                MouseArea {
                    id: reloadArea

                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.redraw()
                }
            }
        }

        Text {
            width: parent.width
            text: root.quote[0]
            font.family: Theme.font
            font.pixelSize: 11
            font.italic: true
            lineHeight: 1.25
            color: Theme.subtext0
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.quote[1] !== ""
            text: "— " + root.quote[1]
            font.family: Theme.font
            font.pixelSize: 10
            color: Theme.overlay0
            elide: Text.ElideRight
        }
    }

    Column {
        id: grid

        anchors.right: parent.right
        anchors.rightMargin: Theme.padCard
        anchors.top: parent.top
        anchors.topMargin: Theme.padCard

        Row {
            Repeater {
                model: root.dayNames

                Text {
                    required property string modelData
                    required property int index

                    width: root.cellWidth
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

                    width: root.cellWidth
                    height: root.cellHeight

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
                        width: Math.min(root.cellWidth, root.cellHeight) - 6
                        height: Math.min(root.cellWidth, root.cellHeight) - 6
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
