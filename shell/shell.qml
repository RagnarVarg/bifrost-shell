//@ pragma UseQApplication
//@ pragma AppId bifrost.shell

import QtQuick
import Quickshell
import qs.Core
import qs.Compositor
// Quickshell only registers qs.* modules reachable from the entry file's
// imports; list every module used by dynamically created components.
import qs.Components.Controls
import qs.Components.Effects
import qs.Components.Glass
import qs.Components.Icons
import qs.Components.Motion
import qs.Components.Popup
import qs.Components.State
import qs.Components.Text
import qs.Modules
import qs.Modules.Bar
import qs.Modules.Bluetooth
import qs.Modules.Idle
import qs.Modules.Bar.Widgets
import qs.Modules.ControlCenter
import qs.Modules.Dock
import qs.Modules.Launcher
import qs.Modules.Launcher.Providers
import qs.Modules.Lock
import qs.Modules.Notifications
import qs.Modules.Overview
import qs.Modules.WindowTransitions
import qs.Modules.Osd
import qs.Modules.PowerMenu
import qs.Modules.Prompt
import qs.Modules.Wallpaper
import qs.Services
import qs.Shared
import qs.Settings
import qs.Settings.Editors

// Bifrost Shell entrypoint:  qs -p <repo>/shell
// Modules: top bar (phase 4); launcher, control center, dock, OSD (phase 5);
// notifications, lock screen, power menu (phase 6); wallpaper (phase 7).
ShellRoot {
    id: shell

    // Survives Quickshell reloads, so "restart" settings are compared against
    // what the process started with.
    PersistentProperties {
        id: processState

        reloadableId: "bifrostProcessState"

        property real startedAt: 0
        // JSON text, not a JS object: JS values cannot cross into the new
        // engine after a Quickshell reload.
        property string valuesJson: ""
    }

    CoreIpc {}

    ModulesIpc {}

    CompositorSync {}

    SystemAppearance {}

    Wallpaper {}

    Bar {}

    Dock {}

    Overview {}

    WindowTransitions {}

    Launcher {}

    ControlCenter {}

    Osd {}

    NotificationPopups {}

    NotificationCenter {}

    PowerMenu {}

    PairingAgent {}

    // polkit has one agent per session: only the session shell asks.
    LazyLoader {
        active: RunMode.isProduction

        PolkitPrompt {}
    }

    Lock {}

    Idle {}

    GreeterSync {}

    // Next to another shell (overlay/nested) blur comes from a runtime rule;
    // as the session shell, CompositorSync applies per-surface rules instead.
    function applySurfaceEffects() {
        if (RunMode.appliesHyprlandSettings)
            return;
        Compositor.ensureSurfaceEffects(RunMode.layerPrefix, { blur: Theme.materials.panel.blur > 0, ignoreAlpha: Theme.materials.panel.blurMask || Theme.glass.blurMask });
    }

    Connections {
        target: Config

        function onSettingChanged(key, value) {
            console.info("[bifrost] setting", key, "=", JSON.stringify(value), "(" + Config.applyModeOf(key) + ")");
            if (key === "materials.blur")
                shell.applySurfaceEffects();
        }
    }

    Component.onCompleted: {
        if (!processState.valuesJson) {
            processState.startedAt = Date.now();
            processState.valuesJson = JSON.stringify(Config.values);
        }
        ApplyState.publish(processState.startedAt, JSON.parse(processState.valuesJson));
        void IconTheme.theme;   // starts live icon-theme switching
        applySurfaceEffects();
        console.info("[bifrost] shell up — mode:", RunMode.mode, "compositor:", Compositor.kind, "config:", Paths.configFile,
            "theme:", Theme.chainIds.join(" → "), "(" + Theme.variant + ")");
        for (const e of Schema.errors)
            console.error("[bifrost] schema error:", e);
        for (const i of Config.issues)
            console.warn("[bifrost] config:", i.message);
    }
}
