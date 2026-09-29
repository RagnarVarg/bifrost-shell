import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Modules.Bar
import qs.Services
import qs.Shared
import qs.Settings

// The clock's menu: time, date and week, weather (Weather service, with its
// unavailable states spelled out), a month calendar with today's events and
// reminders under it (DayPanel), what is playing with
// media controls, and a way to the clock settings. Grows out of the bar
// like every BarMenu.
BarMenu {
    id: menu

    readonly property var cfg: Config.values.clock
    readonly property var menuCfg: cfg.menu || ({})
    readonly property bool showWeather: menuCfg.weather !== false
    readonly property bool showMedia: menuCfg.media !== false
    readonly property string timeFormat: cfg.format === "12h" ? "h:mm AP" : "HH:mm"

    // All three views live inside the same bar menu and glass surface.
    property string view: "clock"
    readonly property real panelWidth: Math.min(
        1040,
        bar && bar.screen ? bar.screen.width - padding * 2 - 48 : 1040)
    readonly property real maxClockHeight: bar && bar.screen ? bar.screen.height - bar.barHeight - padding * 2 - 120 : 660
    readonly property real viewHeight: Math.min(660,
        bar && bar.screen ? bar.screen.height - bar.barHeight - padding * 2 - 120 : 660)
    closeOnLeave: view === "clock" && Config.values.bar.menus.closeOnLeave

    padding: Theme.space.lg

    onIsOpenChanged: {
        if (isOpen) {
            calendar.reset();
            Weather.retain();
            Media.retain();
        } else {
            view = "clock";
            Weather.release();
            Media.release();
        }
    }

    Column {
        width: menu.panelWidth
        spacing: Theme.space.lg

        Row {
            width: parent.width
            spacing: Theme.space.md

            BButton {
                id: backButton
                visible: menu.view !== "clock"
                text: I18n.tr("Back")
                size: "lg"
                onClicked: menu.view = "clock"
            }

            BButton {
                width: (parent.width - parent.spacing - (backButton.visible ? backButton.width + parent.spacing : 0)) / 2
                text: "Wallpaper"
                icon: "display"
                size: "lg"
                selected: menu.view === "wallpaper"
                onClicked: menu.view = "wallpaper"
            }

            BButton {
                width: (parent.width - parent.spacing - (backButton.visible ? backButton.width + parent.spacing : 0)) / 2
                text: "System settings"
                icon: "settings"
                size: "lg"
                selected: menu.view === "settings"
                onClicked: {
                    if (!SettingsNav.page) SettingsNav.open(SettingsNav.firstPage());
                    menu.view = "settings";
                }
            }
        }

        BDivider { width: parent.width }



        Loader {
            width: parent.width
            height: active ? menu.viewHeight : 0
            active: menu.isOpen && menu.view === "wallpaper"
            visible: active
            sourceComponent: WallpaperPicker {
                showHeader: false
                viewportHeight: menu.viewHeight
                onBackRequested: menu.view = "clock"
            }
        }

        Loader {
            width: parent.width
            height: active ? menu.viewHeight : 0
            active: menu.isOpen && menu.view === "settings"
            visible: active
            sourceComponent: SettingsApp {
                embedded: true
                onCloseRequested: menu.view = "clock"
            }
        }

        Flickable {
            visible: menu.view === "clock"
            width: parent.width
            // As tall as its content; scrolls only on a screen too short for it.
            height: Math.min(clockContent.implicitHeight, menu.maxClockHeight)
            contentHeight: clockContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: clockContent
                width: parent.width
                spacing: Theme.space.lg

                // Two columns, so everything fits without scrolling: the time,
                // weather, forecast and media on the left; the calendar with
                // today's events and reminders on the right.
                Row {
                    width: parent.width
                    spacing: Theme.space.xxl

                    Column {
                        id: info

                        width: parent.width - dayColumn.width - parent.spacing
                        spacing: Theme.space.sm

                        BText {
                            text: I18n.tr("Today")
                            role: "overline"
                            tone: "muted"
                        }

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

                        Item {
                            width: 1
                            height: Theme.space.md
                        }

                    Column {
                        width: parent.width
                        visible: menu.showWeather && Weather.daily.length > 0
                        spacing: Theme.space.sm

                        BText {
                            text: I18n.tr("Forecast") + (Weather.stale ? " · " + I18n.tr("Last updated %1").arg(Time.format(Weather.updatedAt, menu.timeFormat)) : "")
                            role: "overline"
                            tone: "muted"
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.space.md

                            Repeater {
                                model: Weather.daily.slice(0, 4)
                                delegate: Rectangle {
                                    id: forecast
                                    required property var modelData
                                    required property int index
                                    width: (parent.width - parent.spacing * (Math.min(4, Weather.daily.length) - 1)) / Math.max(1, Math.min(4, Weather.daily.length))
                                    height: forecastContent.implicitHeight + Theme.space.lg * 2
                                    radius: Theme.radius.md
                                    color: Theme.color.controlFill
                                    border.width: Theme.border.hairline
                                    border.color: Theme.color.hairline

                                    Column {
                                        id: forecastContent
                                        x: Theme.space.lg
                                        y: Theme.space.lg
                                        width: parent.width - Theme.space.lg * 2
                                        spacing: Theme.space.sm

                                        BText {
                                            width: parent.width
                                            text: forecast.index === 0 ? I18n.tr("Today") : Time.format(forecast.modelData.date, "dddd")
                                            role: "label"
                                            elide: Text.ElideRight
                                        }
                                        Row {
                                            spacing: Theme.space.sm
                                            BIcon {
                                                name: Weather.icon(forecast.modelData.code, true)
                                                size: Theme.icon.size.lg
                                                color: Theme.color.iconMuted
                                            }
                                            BText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Weather.degrees(forecast.modelData.max) + " / " + Weather.degrees(forecast.modelData.min)
                                                role: "heading"
                                            }
                                        }
                                        BText {
                                            width: parent.width
                                            text: Weather.describe(forecast.modelData.code)
                                            role: "caption"
                                            tone: "muted"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MediaPanel {
                        expanded: true
                        visible: menu.showMedia
                        width: parent.width
                    }


                    }

                    // The calendar on top, today's events and reminders under it.
                    Column {
                        id: dayColumn

                        width: Math.max(calendar.width, Theme.layout.dayPanelWidth)
                        spacing: Theme.space.xl

                        MonthCalendar {
                            id: calendar

                            anchors.horizontalCenter: parent.horizontalCenter

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: e => calendar.shift(e.angleDelta.y > 0 ? -1 : 1)
                            }
                        }

                        DayPanel {
                            width: parent.width
                            active: menu.isOpen && menu.view === "clock"
                            timeFormat: menu.timeFormat
                        }
                    }
                }

            }

            BScrollIndicator { flickable: parent }
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

        BButton {
            visible: Weather.status === "nolocation"
            text: I18n.tr("Set weather location")
            icon: "settings"
            size: "sm"
            onClicked: {
                SettingsNav.open("clock.weather.location");
                menu.view = "settings";
            }
        }

    }

    // What is playing, with previous / play-pause / next and progress.
}
