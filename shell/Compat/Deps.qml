pragma Singleton

import QtQuick
import Quickshell

// Read-only view of dependencies.json (repo root), the single place where
// external dependencies, minimum versions and version-gated features live.
Singleton {
    id: root

    property var manifest: ({ dependencies: [] })

    function dep(id: string): var {
        return manifest.dependencies.find(d => d.id === id) || null;
    }

    function min(id: string): string {
        const d = dep(id);
        return d && d.min ? d.min : "";
    }

    // Minimum version for a named feature, e.g. feature("hyprland", "hyprctlEval").
    function feature(id: string, name: string): string {
        const d = dep(id);
        return d && d.features && d.features[name] ? d.features[name] : "";
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: {
        const res = reader.read(Platform.shellDir.replace(/\/shell\/?$/, "") + "/dependencies.json");
        if (res.ok)
            manifest = res.data;
        else
            console.error("[bifrost] dependencies.json:", res.error);
    }
}
