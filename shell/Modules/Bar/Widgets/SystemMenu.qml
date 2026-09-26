import QtQuick
import qs.Compat
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Icons
import qs.Components.Text
import qs.Modules.Bar
import qs.Services

// The system menu under the power button, modelled on the macOS Apple menu:
// about, settings and software, recent items, force quit, sleep / restart /
// shut down, lock / log out. About, recent items and force quit open as pages
// in the same menu. Restart, shut down and log out ask for a second click
// (power.confirm); force quit always does. What the run mode forbids is shown
// disabled with the reason.
BarMenu {
    id: menu

    property string page: "main"          // main | about | recent | forceQuit
    property string armed: ""

    readonly property string user: Platform.env("USER")
    readonly property var softwareCandidates: ["org.gnome.Software", "org.kde.discover", "io.github.kolunmi.Bazaar", "pamac-manager", "org.manjaro.pamac.manager", "cachyos-pi", "octopi", "bauh"]
    // Looked up in Apps.all so the binding updates once desktop entries load.
    readonly property var softwareApp: {
        const wanted = Config.values.power.softwareApp;
        const all = Apps.all;
        for (const id of wanted ? [wanted] : softwareCandidates) {
            const app = all.find(a => a.id === id);
            if (app)
                return app;
        }
        return null;
    }

    // Running apps, one row per process.
    readonly property var runningApps: {
        const byPid = {};
        for (const w of Compositor.windows) {
            if (!w.pid || w.pid === Platform.processId)
                continue;
            if (!byPid[w.pid]) {
                const app = Apps.forAppId(w.appId);
                byPid[w.pid] = {
                    pid: w.pid,
                    name: app ? app.name : (w.appId || w.title || String(w.pid)),
                    icon: app ? app.icon : Platform.iconPath(w.appId, "application-x-executable"),
                    windows: 0
                };
            }
            byPid[w.pid].windows++;
        }
        return Object.values(byPid).sort((a, b) => a.name.localeCompare(b.name));
    }

    padding: Theme.space.sm
    onDismissed: {
        page = "main";
        armed = "";
    }

    function run(action) {
        close();
        action();
    }

    // Destructive actions: the first click arms, the second runs.
    function confirmThen(id, needsConfirm, action) {
        if (needsConfirm && armed !== id) {
            armed = id;
            disarm.restart();
            return;
        }
        armed = "";
        action();
    }

    function openPage(p) {
        armed = "";
        page = p;
        if (p === "about")
            SystemInfo.refresh();
        else if (p === "recent")
            RecentFiles.refresh();
    }

    Timer {
        id: disarm

        interval: Theme.motion.duration.emphasis * 10
        onTriggered: menu.armed = ""
    }

    component Line: Item {
        id: line

        property string label: ""
        property string value: ""

        visible: value !== ""
        width: parent.width
        height: Theme.control.height.sm

        BText {
            id: labelText

            anchors.left: parent.left
            anchors.leftMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            text: line.label
            role: "caption"
            tone: "muted"
        }

        BText {
            anchors.left: labelText.right
            anchors.leftMargin: Theme.space.lg
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.md
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: line.value
            role: "caption"
            elide: Text.ElideMiddle
        }
    }

    component Note: BText {
        visible: text !== ""
        width: parent.width - Theme.space.md * 2
        x: Theme.space.md
        topPadding: Theme.space.xs
        bottomPadding: Theme.space.xs
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    Column {
        width: Theme.space.xxxl * 11

        // ── Main ─────────────────────────────────────────────────────────
        Column {
            visible: menu.page === "main"
            width: parent.width

            MenuItem {
                icon: "info"
                text: I18n.tr("About Bifrost")
                onClicked: menu.openPage("about")
            }

            MenuItem {
                separator: true
            }

            MenuItem {
                icon: "settings"
                text: I18n.tr("System Settings…")
                onClicked: menu.run(() => Launch.openSettings(""))
            }

            MenuItem {
                visible: menu.softwareApp !== null
                icon: "package"
                text: I18n.tr("Software…")
                detail: menu.softwareApp ? menu.softwareApp.name : ""
                onClicked: menu.run(() => Apps.launch(menu.softwareApp))
            }

            MenuItem {
                separator: true
            }

            MenuItem {
                icon: "clock"
                text: I18n.tr("Recent Items")
                submenu: true
                onClicked: menu.openPage("recent")
            }

            MenuItem {
                separator: true
            }

            MenuItem {
                icon: "close"
                text: I18n.tr("Force Quit…")
                submenu: true
                enabled: Session.canForceQuit
                onClicked: menu.openPage("forceQuit")
            }

            MenuItem {
                separator: true
            }

            MenuItem {
                icon: "sleep"
                text: I18n.tr("Sleep")
                enabled: Session.canPower
                onClicked: menu.run(() => Session.suspend())
            }

            MenuItem {
                icon: "restart"
                text: menu.armed === "reboot" ? I18n.tr("Click again to restart") : I18n.tr("Restart…")
                armed: menu.armed === "reboot"
                enabled: Session.canPower
                onClicked: menu.confirmThen("reboot", Config.values.power.confirm, () => menu.run(() => Session.reboot()))
            }

            MenuItem {
                icon: "power"
                text: menu.armed === "poweroff" ? I18n.tr("Click again to shut down") : I18n.tr("Shut Down…")
                armed: menu.armed === "poweroff"
                enabled: Session.canPower
                onClicked: menu.confirmThen("poweroff", Config.values.power.confirm, () => menu.run(() => Session.poweroff()))
            }

            MenuItem {
                separator: true
            }

            MenuItem {
                icon: "lock"
                text: I18n.tr("Lock Screen")
                enabled: Session.canLock
                onClicked: menu.run(() => Session.lock())
            }

            MenuItem {
                icon: "logout"
                text: menu.armed === "logout" ? I18n.tr("Click again to log out") : I18n.tr("Log Out %1…").arg(menu.user)
                armed: menu.armed === "logout"
                enabled: Session.canLogout
                onClicked: menu.confirmThen("logout", Config.values.power.confirm, () => menu.run(() => Session.logout()))
            }

            Note {
                text: Session.reason()
            }
        }

        // ── Sub pages share a back row ───────────────────────────────────
        MenuItem {
            visible: menu.page !== "main"
            icon: "chevron-left"
            text: I18n.tr("Back")
            onClicked: menu.openPage("main")
        }

        MenuItem {
            visible: menu.page !== "main"
            separator: true
        }

        // ── About ────────────────────────────────────────────────────────
        Column {
            visible: menu.page === "about"
            width: parent.width

            Row {
                x: Theme.space.md
                height: Theme.control.height.lg + Theme.space.md
                spacing: Theme.space.md

                BIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "file://" + Paths.assetsDir + "/brand/bifrost-mark.svg"
                    size: Theme.icon.size.xl
                    color: Theme.palette.silverBright
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    BText {
                        text: "Bifrost Shell"
                        role: "heading"
                    }

                    BText {
                        text: SystemInfo.values.bifrost ? I18n.tr("Version %1").arg(SystemInfo.values.bifrost) + (SystemInfo.values.bifrostDate ? " · " + SystemInfo.values.bifrostDate : "") : SystemInfo.loading ? I18n.tr("Loading…") : ""
                        role: "caption"
                        tone: "muted"
                    }
                }
            }

            Line {
                label: I18n.tr("Run mode")
                value: SystemInfo.values.runMode || ""
            }

            Line {
                label: "Compositor"
                value: SystemInfo.values.compositor || ""
            }

            Line {
                label: "Quickshell"
                value: SystemInfo.values.quickshell || ""
            }

            Line {
                label: "Qt"
                value: SystemInfo.values.qt || ""
            }

            MenuItem {
                separator: true
            }

            Line {
                label: I18n.tr("System")
                value: SystemInfo.values.os || ""
            }

            Line {
                label: I18n.tr("Kernel")
                value: SystemInfo.values.kernel || ""
            }

            Line {
                label: I18n.tr("Computer")
                value: SystemInfo.values.host || ""
            }

            Line {
                label: I18n.tr("Processor")
                value: SystemInfo.values.cpu ? SystemInfo.values.cpu + (SystemInfo.values.cores ? " " + I18n.tr("(%1 threads)").arg(SystemInfo.values.cores) : "") : ""
            }

            Line {
                label: I18n.tr("Graphics")
                value: GpuStats.available ? GpuStats.name + (GpuStats.memTotalMb > 0 ? " · " + (GpuStats.memTotalMb / 1024).toFixed(0) + " GB" : "") : ""
            }

            Line {
                label: I18n.tr("Memory")
                value: SystemStats.memTotalKb > 0 ? (SystemStats.memTotalKb / 1048576).toFixed(0) + " GB" : ""
            }

            Line {
                label: I18n.tr("Uptime")
                value: SystemInfo.refreshedAt > 0 ? SystemInfo.uptimeText() : ""
            }
        }

        // ── Recent items ─────────────────────────────────────────────────
        Column {
            visible: menu.page === "recent"
            width: parent.width

            Repeater {
                model: menu.page === "recent" ? RecentFiles.items : []

                delegate: MenuItem {
                    required property var modelData

                    image: modelData.icon
                    text: modelData.name
                    onClicked: menu.run(() => RecentFiles.open(modelData))
                }
            }

            Note {
                text: RecentFiles.items.length === 0 ? I18n.tr("No recent items") : ""
            }
        }

        // ── Force quit ───────────────────────────────────────────────────
        Column {
            visible: menu.page === "forceQuit"
            width: parent.width

            Repeater {
                model: menu.page === "forceQuit" ? menu.runningApps : []

                delegate: MenuItem {
                    required property var modelData
                    readonly property string key: "quit:" + modelData.pid

                    image: modelData.icon
                    text: modelData.name
                    detail: modelData.windows > 1 ? I18n.tr("%n windows", modelData.windows) : ""
                    armed: menu.armed === key
                    onClicked: menu.confirmThen(key, true, () => Session.forceQuit(modelData.pid))
                }
            }

            Note {
                text: menu.runningApps.length === 0 ? I18n.tr("No open apps") : menu.armed.startsWith("quit:") ? I18n.tr("Click again to force the app to quit. Unsaved changes are lost.") : I18n.tr("Choose an app that isn't responding.")
                tone: menu.armed.startsWith("quit:") ? "danger" : "muted"
            }
        }
    }
}
