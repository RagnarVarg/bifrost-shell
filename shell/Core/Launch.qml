pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Starts other Bifrost apps (separate processes).
Singleton {
    function openSettings(page: string) {
        Platform.execDetached(["bash", Paths.repoDir + "/scripts/settings.sh", page || ""]);
    }
}
