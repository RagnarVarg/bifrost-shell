pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Installed applications (desktop entries), normalised:
//   { id, name, genericName, comment, icon (URL), keywords, entry }
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => normalise(e)).sort((a, b) => a.name.localeCompare(b.name))

    function normalise(e) {
        return {
            id: e.id,
            name: e.name,
            genericName: e.genericName || "",
            comment: e.comment || "",
            icon: Platform.iconPath(e.icon, "application-x-executable"),
            keywords: (e.keywords || []).join(" "),
            entry: e
        };
    }

    function byId(id: string): var {
        const e = DesktopEntries.byId(id);
        return e ? normalise(e) : null;
    }

    // Best match for a window's app id (class), e.g. "vivaldi-stable".
    function forAppId(appId: string): var {
        if (!appId)
            return null;
        const e = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        return e ? normalise(e) : null;
    }

    function newWindowAction(app) {
        if (!app || !app.entry) return null;
        return Array.from(app.entry.actions || []).find(a =>
            String(a.id).toLowerCase().replace(/[-_ ]/g, "") === "newwindow") || null;
    }

    function supportsNewWindow(app) {
        if (!app || !app.entry) return false;
        const executable=String(app.entry.command[0] || "").split("/").pop();
        return !!newWindowAction(app) || ["kitty", "mpv"].indexOf(executable) >= 0;
    }

    function launchNewWindow(app) {
        const action=newWindowAction(app);
        if (action && action.command.length)
            Platform.launch(action.command, {appId:app.id, workingDirectory:app.entry.workingDirectory});
        else launch(app);
    }

    // What DesktopEntry.execute() does, but through Platform.launch so the
    // app outlives the shell.
    function launch(app) {
        if (app && app.entry && app.entry.command.length)
            Platform.launch(app.entry.command, { appId: app.id, workingDirectory: app.entry.workingDirectory });
    }
}
