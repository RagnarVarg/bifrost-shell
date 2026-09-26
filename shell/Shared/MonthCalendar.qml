import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.State
import qs.Components.Text

// A month of days: month and year with previous/next, weekday initials in
// the clock locale's order (its first day of the week), ISO week numbers
// when clock.weekNumber is on, today marked with the accent. Clicking the
// title returns to the current month.
Column {
    id: cal

    readonly property var today: Time.now
    // First day of the month shown.
    property var month: new Date(today.getFullYear(), today.getMonth(), 1)
    readonly property bool weeks: Config.values.clock.weekNumber === true
    readonly property real cell: Theme.control.height.sm
    // Qt: 1 = Monday … 7 = Sunday; JS Date: 0 = Sunday.
    readonly property int firstDay: Time.locale.firstDayOfWeek % 7
    readonly property bool showingToday: month.getFullYear() === today.getFullYear() && month.getMonth() === today.getMonth()

    // The 42 days of the 6 × 7 grid, starting on the week's first day.
    readonly property var days: {
        const lead = (month.getDay() - firstDay + 7) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(month.getFullYear(), month.getMonth(), 1 - lead + i));
        return out;
    }

    function shift(n: int) {
        month = new Date(month.getFullYear(), month.getMonth() + n, 1);
    }

    function reset() {
        month = new Date(today.getFullYear(), today.getMonth(), 1);
    }

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: Theme.space.xs
    width: cell * (weeks ? 8 : 7)

    Item {
        width: parent.width
        height: Theme.control.height.md

        Item {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: titleText.implicitWidth + Theme.space.md * 2
            height: Theme.control.height.sm

            StateLayer {
                anchors.fill: parent
                radius: Theme.control.radius
                hovered: titleMouse.containsMouse && !cal.showingToday
                pressed: titleMouse.pressed && !cal.showingToday
            }

            BText {
                id: titleText

                anchors.centerIn: parent
                text: Time.format(cal.month, "MMMM yyyy")
                role: "label"
            }

            MouseArea {
                id: titleMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: cal.showingToday ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: cal.reset()
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.xxs

            BIconButton {
                icon: "chevron-left"
                size: "sm"
                onClicked: cal.shift(-1)
            }

            BIconButton {
                icon: "chevron-right"
                size: "sm"
                onClicked: cal.shift(1)
            }
        }
    }

    // Weekday initials
    Row {
        Item {
            visible: cal.weeks
            width: cal.cell
            height: cal.cell
        }

        Repeater {
            model: 7

            delegate: BText {
                required property int index

                width: cal.cell
                height: cal.cell
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Time.locale.dayName((cal.firstDay + index) % 7, Locale.ShortFormat).slice(0, 2)
                role: "caption"
                tone: "faint"
            }
        }
    }

    Repeater {
        model: 6

        delegate: Row {
            id: week

            required property int index
            readonly property var dates: cal.days.slice(index * 7, index * 7 + 7)

            BText {
                visible: cal.weeks
                width: cal.cell
                height: cal.cell
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: Time.isoWeek(week.dates[3])
                role: "mono"
                tone: "faint"
            }

            Repeater {
                model: week.dates

                delegate: Item {
                    id: day

                    required property var modelData
                    readonly property bool isToday: cal.sameDay(modelData, cal.today)
                    readonly property bool inMonth: modelData.getMonth() === cal.month.getMonth()

                    width: cal.cell
                    height: cal.cell

                    Rectangle {
                        visible: day.isToday
                        anchors.centerIn: parent
                        width: cal.cell - Theme.space.xs
                        height: width
                        radius: width / 2
                        color: Theme.color.accent
                    }

                    BText {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        role: day.isToday ? "label" : "body"
                        color: day.isToday ? Theme.color.onAccent : day.inMonth ? Theme.color.text : Theme.color.textFaint
                    }
                }
            }
        }
    }
}
