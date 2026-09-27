import QtQuick
import qs.Core
import qs.Services
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text

// Under the clock menu's calendar: today's events (Calendar service, read
// from the system calendars; the one on now or next is marked) and a short
// list of reminders made and checked off here (Reminders, kept across
// restarts). Without a calendar it says so; no sample data.
Column {
    id: day

    // Fetch events only while shown (the menu is open).
    property bool active: false
    property string timeFormat: "HH:mm"
    readonly property real timeWidth: Math.max(timeProbe.implicitWidth, allDayProbe.implicitWidth)

    spacing: Theme.space.lg

    onActiveChanged: active ? Calendar.retain() : Calendar.release()
    Component.onDestruction: if (active) Calendar.release()

    // Width of the time column: the widest time this format gives.
    BText {
        id: timeProbe

        visible: false
        role: "label"
        text: Time.format(new Date(2000, 0, 1, 22, 58), day.timeFormat)
    }

    BText {
        id: allDayProbe

        visible: false
        role: "label"
        text: I18n.tr("All day")
    }

    // ── Events ──
    Column {
        width: parent.width
        spacing: Theme.space.sm

        BText {
            text: I18n.tr("Today's events")
            role: "overline"
            tone: "muted"
        }

        Row {
            visible: Calendar.status === "unavailable"
            width: parent.width
            spacing: Theme.space.sm

            BIcon {
                name: "info"
                size: Theme.icon.size.sm
                color: Theme.color.iconMuted
            }

            BText {
                width: parent.width - Theme.icon.size.sm - parent.spacing
                text: I18n.tr("No calendar connected") + (Calendar.reason ? " · " + I18n.tr(Calendar.reason) : "")
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }
        }

        BText {
            visible: Calendar.status === "loading" && Calendar.events.length === 0
            text: I18n.tr("Loading…")
            role: "caption"
            tone: "faint"
        }

        BText {
            visible: Calendar.status === "ok" && Calendar.events.length === 0
            text: I18n.tr("No events today")
            role: "caption"
            tone: "faint"
        }

        Repeater {
            model: Calendar.status === "ok" ? Calendar.events : []

            delegate: Rectangle {
                id: event

                required property var modelData
                readonly property bool isNext: Calendar.next !== null && Calendar.next.start === modelData.start && Calendar.next.title === modelData.title
                readonly property bool now: isNext && modelData.start <= Time.now.getTime()
                readonly property bool past: !modelData.allDay && modelData.end <= Time.now.getTime()

                width: parent.width
                height: eventRow.implicitHeight + (isNext ? Theme.space.sm * 2 : Theme.space.xs * 2)
                radius: Theme.radius.md
                color: isNext ? Theme.color.controlFill : "transparent"

                Rectangle {
                    visible: event.isNext
                    x: 0
                    y: Theme.space.sm
                    width: Theme.border.focus
                    height: parent.height - Theme.space.sm * 2
                    radius: width / 2
                    color: Theme.color.accent
                }

                Row {
                    id: eventRow

                    x: Theme.space.md
                    y: event.isNext ? Theme.space.sm : Theme.space.xs
                    width: parent.width - Theme.space.md * 2
                    spacing: Theme.space.md

                    BText {
                        width: day.timeWidth
                        text: event.modelData.allDay ? I18n.tr("All day") : Time.format(new Date(event.modelData.start), day.timeFormat)
                        role: "label"
                        tone: event.past ? "faint" : event.isNext ? "accent" : "muted"
                        elide: Text.ElideRight
                    }

                    Column {
                        width: parent.width - day.timeWidth - parent.spacing
                        spacing: Theme.space.xxs

                        BText {
                            width: parent.width
                            text: event.modelData.title || I18n.tr("(No title)")
                            role: "label"
                            tone: event.past ? "faint" : "primary"
                            elide: Text.ElideRight
                        }

                        BText {
                            width: parent.width
                            visible: text !== ""
                            // One line per event; the next one also says until when.
                            text: [event.now ? I18n.tr("Now") : event.isNext ? I18n.tr("Next") : "",
                                event.isNext ? I18n.tr("until %1").arg(Time.format(new Date(event.modelData.end), day.timeFormat)) : "",
                                event.modelData.location].filter(s => s).join(" · ")
                            role: "caption"
                            tone: event.isNext ? "accent" : "faint"
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ── Reminders ──
    Column {
        width: parent.width
        spacing: Theme.space.sm

        Item {
            width: parent.width
            height: Math.max(remindersTitle.implicitHeight, clearDone.visible ? clearDone.height : 0)

            BText {
                id: remindersTitle

                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Reminders")
                role: "overline"
                tone: "muted"
            }

            BButton {
                id: clearDone

                visible: Reminders.doneCount > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "ghost"
                size: "sm"
                text: I18n.tr("Clear done")
                onClicked: Reminders.clearDone()
            }
        }

        BTextField {
            id: field

            width: parent.width
            placeholder: I18n.tr("Add a reminder")
            icon: "plus"
            onAccepted: t => {
                Reminders.add(t);
                field.text = "";
            }
        }

        Repeater {
            model: Reminders.items

            delegate: Item {
                id: reminder

                required property var modelData

                width: parent.width
                height: Math.max(Theme.control.height.sm, reminderText.implicitHeight)

                HoverHandler {
                    id: hover
                }

                // Check box: click it (or the text) to check the reminder off.
                Rectangle {
                    id: box

                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.icon.size.md
                    height: width
                    radius: width / 2
                    color: reminder.modelData.done ? Theme.color.accent : "transparent"
                    border.width: reminder.modelData.done ? 0 : Theme.border.focus
                    border.color: Theme.color.iconMuted

                    BIcon {
                        anchors.centerIn: parent
                        visible: reminder.modelData.done
                        name: "check"
                        size: Theme.icon.size.sm
                        color: Theme.color.onAccent
                    }
                }

                BText {
                    id: reminderText

                    anchors.verticalCenter: parent.verticalCenter
                    x: box.width + Theme.space.md
                    width: parent.width - x - remove.width - Theme.space.sm
                    text: reminder.modelData.text
                    role: "body"
                    tone: reminder.modelData.done ? "faint" : "primary"
                    font.strikeout: reminder.modelData.done
                    wrapMode: Text.Wrap
                }

                MouseArea {
                    anchors.left: parent.left
                    anchors.right: reminderText.right
                    height: parent.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Reminders.toggle(reminder.modelData.id)
                }

                BIconButton {
                    id: remove

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    size: "sm"
                    opacity: hover.hovered ? 1 : 0
                    enabled: hover.hovered
                    onClicked: Reminders.remove(reminder.modelData.id)
                }
            }
        }

        BText {
            visible: Reminders.items.length === 0
            text: I18n.tr("No reminders")
            role: "caption"
            tone: "faint"
        }
    }
}
