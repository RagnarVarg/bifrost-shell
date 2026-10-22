import QtQuick
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.State
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar
import qs.Modules.ControlCenter
import qs.Services
import qs.Shared
import qs.Settings

// The clock's menu: time, date and week, the control center
// (ControlCenterContent), a month calendar with today's events and reminders
// under it (DayPanel), and what is playing with media controls. Weather
// (Weather service, with its unavailable states spelled out), Hardware (CPU
// and GPU temperature, memory, storage), the wallpaper picker and Settings
// are pages of their own. Grows out of the bar like
// every BarMenu.
BarMenu {
    id: menu

    readonly property var cfg: Config.values.clock
    readonly property var menuCfg: cfg.menu || ({})
    readonly property bool showWeather: menuCfg.weather !== false
    readonly property bool showMedia: menuCfg.media !== false
    readonly property string timeFormat: cfg.format === "12h" ? "h:mm AP" : "HH:mm"

    // All views live inside the same bar menu and glass surface.
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
            // For the control center on the first page and the Hardware page.
            SystemStats.retain();
            GpuStats.retain();
            Vpn.retain();
            Disks.retain();
            Power.refresh();
        } else {
            view = "clock";
            ShellState.controlCenterDetail = "";
            Weather.release();
            Media.release();
            SystemStats.release();
            GpuStats.release();
            Vpn.release();
            Disks.release();
        }
    }

    Column {
        width: menu.panelWidth
        spacing: Theme.space.lg

        Row {
            readonly property int pages: weatherButton.visible ? 4 : 3
            readonly property real pageButtonWidth: (width - spacing * (pages - 1) - (backButton.visible ? backButton.width + spacing : 0)) / pages

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
                id: weatherButton
                visible: menu.showWeather
                width: parent.pageButtonWidth
                text: I18n.tr("Weather")
                icon: "cloud"
                size: "lg"
                selected: menu.view === "weather"
                onClicked: menu.view = "weather"
            }

            BButton {
                width: parent.pageButtonWidth
                text: I18n.tr("Hardware")
                icon: "cpu"
                size: "lg"
                selected: menu.view === "hardware"
                onClicked: menu.view = "hardware"
            }

            BButton {
                width: parent.pageButtonWidth
                text: "Wallpaper"
                icon: "display"
                size: "lg"
                selected: menu.view === "wallpaper"
                onClicked: menu.view = "wallpaper"
            }

            BButton {
                width: parent.pageButtonWidth
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
            active: menu.isOpen && menu.view === "weather"
            visible: active
            sourceComponent: WeatherView {}
        }

        Loader {
            width: parent.width
            active: menu.isOpen && menu.view === "hardware"
            visible: active
            sourceComponent: HardwareView {}
        }

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
                // control center and media on the left; the calendar with
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
                            width: 1
                            height: Theme.space.md
                        }

                        BDivider { width: parent.width }

                        ControlCenterContent {
                            width: parent.width
                            inset: 0
                            onCloseRequested: menu.close()
                        }

                        Item {
                            width: 1
                            height: Theme.space.md
                        }

                        // The control center shows media itself when it is on.
                        MediaPanel {
                            expanded: true
                            visible: menu.showMedia && !Config.values.controlCenter.showMedia
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

    // The weather page: weather now, then the next days.
    component WeatherView: Column {
        spacing: Theme.space.xl

        WeatherPanel {
            width: parent.width
            timeFormat: menu.timeFormat
        }

            Column {
                width: parent.width
                visible: Weather.daily.length > 0
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
    }

    // The hardware page: processor, graphics card and memory side by side,
    // then every local disk with how full it is.
    component HardwareView: Column {
        id: hardware

        readonly property real warn: Config.values.systemStats.warnPercent / 100

        spacing: Theme.space.xl

        Row {
            id: cards

            readonly property int count: GpuStats.available ? 3 : 2

            width: parent.width
            spacing: Theme.space.md

            Card {
                width: (cards.width - cards.spacing * (cards.count - 1)) / cards.count
                icon: "cpu"
                title: I18n.tr("Processor")
                temperature: SystemStats.cpuTemp
                lines: [[I18n.tr("Usage"), Math.round(SystemStats.cpu * 100) + " %", SystemStats.cpu >= hardware.warn]]
            }

            Card {
                visible: GpuStats.available
                width: (cards.width - cards.spacing * (cards.count - 1)) / cards.count
                icon: "display"
                title: GpuStats.name || "GPU"
                temperature: GpuStats.temperature
                lines: [[I18n.tr("Usage"), Math.round(GpuStats.usage * 100) + " %", GpuStats.usage >= hardware.warn]]
                    .concat(GpuStats.memTotalMb > 0 ? [["VRAM", (GpuStats.memUsedMb / 1024).toFixed(1) + " / " + (GpuStats.memTotalMb / 1024).toFixed(0) + " GB", false]] : [])
            }

            Card {
                width: (cards.width - cards.spacing * (cards.count - 1)) / cards.count
                icon: "memory"
                title: I18n.tr("Memory")
                temperature: NaN
                lines: [["RAM", (SystemStats.memUsedKb / 1048576).toFixed(1) + " / " + (SystemStats.memTotalKb / 1048576).toFixed(0) + " GB", SystemStats.mem >= hardware.warn],
                        [I18n.tr("Usage"), Math.round(SystemStats.mem * 100) + " %", SystemStats.mem >= hardware.warn]]
            }
        }

        Column {
            width: parent.width
            spacing: Theme.space.md

            BText {
                text: I18n.tr("Storage")
                role: "overline"
                tone: "muted"
            }

            BText {
                visible: Disks.loaded && Disks.disks.length === 0
                text: I18n.tr("No disks found")
                role: "caption"
                tone: "muted"
            }

            Repeater {
                model: Disks.disks
                delegate: Column {
                    id: disk

                    required property var modelData
                    readonly property real full: modelData.size > 0 ? modelData.used / modelData.size : 0

                    width: parent.width
                    spacing: Theme.space.xs

                    Item {
                        width: parent.width
                        height: diskName.implicitHeight

                        Row {
                            spacing: Theme.space.sm

                            BIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "drive"
                                size: Theme.icon.size.sm
                                color: Theme.color.iconMuted
                            }

                            BText {
                                id: diskName
                                text: disk.modelData.mount === "/" ? I18n.tr("System disk") : disk.modelData.mount.split("/").pop()
                                role: "label"
                            }

                            BText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: disk.modelData.mount + "  ·  " + disk.modelData.type
                                role: "caption"
                                tone: "faint"
                            }
                        }

                        BText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("%1 free of %2").arg(Disks.bytes(disk.modelData.avail)).arg(Disks.bytes(disk.modelData.size))
                            role: "mono"
                            tone: disk.full >= hardware.warn ? "warning" : "muted"
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Theme.space.sm
                        radius: height / 2
                        color: Theme.color.track

                        Rectangle {
                            width: Math.max(height, parent.width * disk.full)
                            height: parent.height
                            radius: height / 2
                            color: disk.full >= hardware.warn ? Theme.color.warning : Theme.color.trackActive
                        }
                    }
                }
            }
        }
    }

    // One hardware card: a title, the temperature large, then label/value lines.
    component Card: Rectangle {
        id: card

        property string icon: ""
        property string title: ""
        property real temperature: NaN
        // [[label, value, warn]]
        property var lines: []

        height: cardContent.implicitHeight + Theme.space.lg * 2
        radius: Theme.radius.md
        color: Theme.color.controlFill
        border.width: Theme.border.hairline
        border.color: Theme.color.hairline

        Column {
            id: cardContent

            x: Theme.space.lg
            y: Theme.space.lg
            width: parent.width - Theme.space.lg * 2
            spacing: Theme.space.sm

            Row {
                width: parent.width
                spacing: Theme.space.sm

                BIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: card.icon
                    size: Theme.icon.size.sm
                    color: Theme.color.iconMuted
                }

                BText {
                    width: parent.width - Theme.icon.size.sm - parent.spacing
                    text: card.title
                    role: "label"
                    elide: Text.ElideRight
                }
            }

            BText {
                text: isNaN(card.temperature) ? "–" : Math.round(card.temperature) + " °C"
                role: "display"
                tone: isNaN(card.temperature) ? "faint" : "primary"
            }

            BText {
                text: isNaN(card.temperature) ? " " : I18n.tr("Temperature")
                role: "caption"
                tone: "muted"
            }

            Repeater {
                model: card.lines
                delegate: Item {
                    required property var modelData

                    width: cardContent.width
                    height: Theme.control.height.sm

                    BText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[0]
                        role: "caption"
                        tone: "muted"
                    }

                    BText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData[1]
                        role: "mono"
                        tone: parent.modelData[2] ? "warning" : "primary"
                    }
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
