pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Services

Singleton {
    id: root

    readonly property int activeWorkspaceId: Hyprland.focusedWorkspace?.id ?? -1
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hypr-floatmode/workspaces"
    readonly property string togglerPath: Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-floatmode-toggle.sh"
    readonly property string modeFilePath: activeWorkspaceId > 0 ? (stateDir + "/" + activeWorkspaceId + "/mode") : ""

    property string _rawMode: ""
    readonly property bool isFloating: _rawMode.trim() === "floating"

    FileView {
        id: modeFileView
        path: root.modeFilePath
        blockLoading: false
        watchChanges: true
        printErrors: false

        onLoaded: root._rawMode = text()
        onLoadFailed: root._rawMode = ""
        onFileChanged: reload()
    }

    onModeFilePathChanged: modeFileView.reload()

    function toggle() {
        if (root.activeWorkspaceId <= 0)
            return;
        Quickshell.execDetached(["bash", root.togglerPath, String(root.activeWorkspaceId)]);
    }
}
