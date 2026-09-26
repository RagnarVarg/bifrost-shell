import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Modules.Bar
import qs.Services
import qs.Shared

// The clock's menu: time, date and week, weather (Weather service, with its
// unavailable states spelled out), a month calendar, what is playing with
// media controls, and a way to the clock settings. Grows out of the bar
// like every BarMenu.
BarMenu {
    id: menu

    readonly property var cfg: Config.values.clock
    readonly property var menuCfg: cfg.menu || ({})
    readonly property bool showWeather: menuCfg.weather !== false
    readonly property bool showMedia: menuCfg.media !== false && Media.available
    readonly property string timeFormat: cfg.format === "12h" ? "h:mm AP" : "HH:mm"

    padding: Theme.space.lg

    onIsOpenChanged: {
        if (isOpen) {
            calendar.reset();
            Weather.retain();
            Media.retain();
        } else {
            Weather.release();
            Media.release();
        }
    }

    Column {
        width: Theme.layout.clockMenuWidth
        spacing: Theme.space.lg

        Row {
            width: parent.width
            spacing: Theme.space.xl

            Column {
                id: info

                width: parent.width - calendar.width - parent.spacing
                spacing: Theme.space.xs

                BText {
                    text: Time.format(Time.now, menu.timeFormat)
                    role: "display"
                }

                BText {
                    width: parent.width
                    text: Time.format(Time.now, "dddd d MMMM yyyy")
                    role: "label"
                    tone: "muted"
                    elide: Text.ElideRight
                }

                BText {
                    text: I18n.tr("Week %1").arg(Time.isoWeek(Time.now))
                    role: "caption"
                    tone: "faint"
                }

                Item {
                    visible: menu.showWeather
                    width: 1
                    height: Theme.space.md
                }

                BDivider {
                    visible: menu.showWeather
                    width: parent.width
                }

                Item {
                    visible: menu.showWeather
                    width: 1
                    height: Theme.space.sm
                }

                WeatherPanel {
                    visible: menu.showWeather
                    width: parent.width
                    timeFormat: menu.timeFormat
                }
            }

            MonthCalendar {
                id: calendar

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => calendar.shift(e.angleDelta.y > 0 ? -1 : 1)
                }
            }
        }

        MediaPanel {
            visible: menu.showMedia
            width: parent.width
        }

        Item {
            width: parent.width
            height: settingsButton.implicitHeight

            BButton {
                id: settingsButton

                anchors.right: parent.right
                icon: "settings"
                text: I18n.tr("Clock & date settings…")
                size: "sm"
                onClicked: {
                    menu.close();
                    Launch.openSettings("clock");
                }
            }
        }
    }

    // Weather now, today's range and the next days; or why there is none.
    component WeatherPanel: Column {
        id: weather

        property string timeFormat: "HH:mm"
        readonly property var now: Weather.current
        readonly property string problem: ({
                nolocation: I18n.tr("No location: set one under Appearance → Location, or a time zone"),
                offline: I18n.tr("Offline"),
                error: I18n.tr("The weather service did not answer")
            })[Weather.status] || ""

        spacing: Theme.space.sm

        // Data (fresh or last known)
        Row {
            width: parent.width
            visible: now !== null
            spacing: Theme.space.md

            BIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: now ? Weather.icon(now.code, now.isDay) : "cloud"
                size: Theme.icon.size.xl
                color: Weather.stale ? Theme.color.iconMuted : Theme.color.text
            }

            Column {
                width: Math.max(0,parent.width-Theme.icon.size.xl-parent.spacing)
                anchors.verticalCenter: parent.verticalCenter

                BText {
                    text: now ? Weather.degrees(now.temperature) + "  " + Weather.describe(now.code) : ""
                    width: parent.width
                    wrapMode: Text.WordWrap
                    role: "heading"
                    tone: Weather.stale ? "muted" : "primary"
                }

                BText {
                    text: {
                        if (!now)
                            return "";
                        const today = Weather.daily[0];
                        const parts = [I18n.tr("Feels like %1").arg(Weather.degrees(now.feelsLike))];
                        if (today)
                            parts.push("↑" + Weather.degrees(today.max) + " ↓" + Weather.degrees(today.min));
                        if (Weather.place)
                            parts.push(Weather.place);
                        return parts.join("  ·  ");
                    }
                    width: parent.width
                    wrapMode: Text.WordWrap
                    role: "caption"
                    tone: "muted"
                }
            }
        }

        Flow {
            width: parent.width
            visible: now !== null && Weather.daily.length > 1
            spacing: Theme.space.lg

            Repeater {
                model: Weather.daily.slice(1, 4)

                delegate: Row {
                    required property var modelData

                    spacing: Theme.space.xs

                    BText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Time.format(modelData.date, "ddd")
                        role: "caption"
                        tone: "muted"
                    }

                    BIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.icon(modelData.code, true)
                        size: Theme.icon.size.sm
                        color: Theme.color.iconMuted
                    }

                    BText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.degrees(modelData.max) + " " + Weather.degrees(modelData.min)
                        role: "mono"
                        tone: "muted"
                    }
                }
            }
        }

        // Status line: loading, or why the data is missing or old.
        Row {
            visible: Weather.status === "loading" || problem !== ""
            spacing: Theme.space.sm

            BIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: problem !== ""
                name: Weather.status === "offline" ? "cloud" : "warning"
                size: Theme.icon.size.sm
                color: Theme.color.iconMuted
            }

            BText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, weather.width - Theme.icon.size.sm - Theme.space.sm)
                wrapMode: Text.Wrap
                text: Weather.status === "loading" ? I18n.tr("Loading weather…") : Weather.stale ? I18n.tr("%1 · last updated %2").arg(problem).arg(Time.format(Weather.updatedAt, weather.timeFormat)) : I18n.tr("Weather unavailable: %1").arg(problem)
                role: "caption"
                tone: Weather.status === "loading" ? "faint" : "muted"
            }
        }
    }

    // What is playing, with previous / play-pause / next and progress.
}
