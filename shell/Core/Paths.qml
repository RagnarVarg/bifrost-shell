pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Every filesystem location Bifrost uses. Nothing outside these paths is ever
// written; in particular never ~/.config/hypr or ~/.config/DankMaterialShell.
Singleton {
    id: root

    readonly property string home: Platform.env("HOME")
    readonly property string xdgConfig: Platform.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string xdgRuntime: Platform.env("XDG_RUNTIME_DIR") || "/tmp"

    // Source tree (shell/ is Quickshell's config root, the repo is its parent).
    readonly property string shellDir: Platform.shellDir
    readonly property string repoDir: shellDir.replace(/\/shell\/?$/, "")
    readonly property string schemaDir: repoDir + "/schema"
    readonly property string themesDir: repoDir + "/themes"
    readonly property string presetsDir: repoDir + "/presets"
    readonly property string assetsDir: repoDir + "/assets"

    // User config. BIFROST_CONFIG_DIR exists for tests (the selftest points it
    // at a scratch dir); normal runs, dev included, use ~/.config/bifrost.
    readonly property string configDir: Platform.env("BIFROST_CONFIG_DIR") || xdgConfig + "/bifrost"
    readonly property string configFile: configDir + "/config.json"
    readonly property string userThemesDir: configDir + "/themes"
    readonly property string userPresetsDir: configDir + "/presets"
    readonly property string profilesDir: configDir + "/profiles"
    readonly property string backupsDir: configDir + "/backups"
    readonly property string stateFile: configDir + "/state.json"
    readonly property string hyprDir: configDir + "/hypr"

    // Ephemeral per-session data (cleared at logout).
    readonly property string runtimeDir: xdgRuntime + "/bifrost" + (Platform.env("BIFROST_CONFIG_DIR") ? "-test" : "")
    readonly property string appliedFile: runtimeDir + "/applied.json"
}
