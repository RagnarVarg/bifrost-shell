import QtQuick
import qs.Modules.Bar.Widgets

// Instantiates a bar widget by id. Widgets are declared statically here
// (Quickshell cannot load files outside the import graph by URL). Unknown or
// not-yet-built ids render nothing.
//
// The host is in bar coordinates (see BarWindow): its width is the widget's
// length along the bar. On a side bar the widget is turned back upright, as
// wide as the bar is thick, and its length is its height (BarWidget.length).
Item {
    id: host

    property var entry: ({})
    property var bar: null
    readonly property alias item: loader.item
    readonly property bool vertical: bar ? bar.vertical === true : false

    signal loaded

    readonly property var components: ({
            launcher: launcher,
            screenshot: screenshot,
            workspaces: workspaces,
            activeWindow: activeWindow,
            clock: clock,
            battery: battery,
            media: media,
            systemStats: systemStats,
            gpu: gpu,
            tray: tray,
            settings: settings,
            controlCenter: controlCenter,
            status: status,
            network: network,
            vpn: vpn,
            bluetooth: bluetooth,
            audio: audio,
            display: display,
            notifications: notifications,
            power: power,
            spacer: spacer
        })

    implicitWidth: item ? (item.length !== undefined ? item.length : item.implicitWidth) : 0
    height: parent ? parent.height : 0

    Loader {
        id: loader

        width: host.vertical ? host.height : host.width
        height: host.vertical ? host.width : host.height
        // Whole-pixel turn (not around the centre) so text stays sharp.
        transform: [
            Rotation {
                angle: host.vertical ? -90 : 0
            },
            Translate {
                y: host.vertical ? host.height : 0
            }
        ]
        sourceComponent: host.components[host.entry.id] || null
        onLoaded: {
            item.entry = Qt.binding(() => host.entry);
            item.bar = Qt.binding(() => host.bar);
            host.loaded();
        }
    }

    Component { id: screenshot; ScreenshotWidget {} }

    Component {
        id: launcher

        LauncherWidget {}
    }

    Component {
        id: workspaces

        WorkspacesWidget {}
    }

    Component {
        id: activeWindow

        ActiveWindowWidget {}
    }

    Component {
        id: media
        MediaWidget {}
    }

    Component {
        id: battery
        BatteryWidget {}
    }

    Component {
        id: clock

        ClockWidget {}
    }

    Component {
        id: systemStats

        SystemStatsWidget {}
    }

    Component {
        id: gpu

        GpuWidget {}
    }

    Component {
        id: tray

        TrayWidget {}
    }

    Component {
        id: settings

        SettingsWidget {}
    }

    Component {
        id: controlCenter

        ControlCenterWidget {}
    }

    Component {
        id: display

        DisplayWidget {}
    }

    Component {
        id: status

        StatusWidget {}
    }

    // The status icons one by one, so each can be placed on its own.
    Component {
        id: network

        StatusWidget {
            parts: ["network"]
        }
    }

    Component {
        id: vpn

        StatusWidget {
            parts: ["vpn"]
        }
    }

    Component {
        id: bluetooth

        StatusWidget {
            parts: ["bluetooth"]
        }
    }

    Component {
        id: audio

        StatusWidget {
            parts: ["audio"]
        }
    }

    Component {
        id: notifications

        NotificationsWidget {}
    }

    Component {
        id: power

        PowerWidget {}
    }

    Component {
        id: spacer

        SpacerWidget {}
    }
}
