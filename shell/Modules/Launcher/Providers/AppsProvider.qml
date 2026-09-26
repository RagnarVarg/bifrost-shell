import QtQuick
import qs.Core
import qs.Services

// Launcher provider contract (all providers implement this):
//   id, label
//   search(query) -> [{ key, title, subtitle, icon, score, run() }]
// Higher score ranks first; an empty query lists the provider's default set.
// Future providers (recent apps, commands, system actions) plug in beside
// this one without touching the launcher UI.
QtObject {
    readonly property string id: "apps"
    readonly property string label: I18n.tr("Apps")

    function score(app, q) {
        if (!q)
            return 1;
        const name = app.name.toLowerCase();
        if (name.startsWith(q))
            return 100 - Math.min(20, name.length - q.length);
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 80;
        if (name.indexOf(q) >= 0)
            return 60;
        if ((app.genericName + " " + app.keywords).toLowerCase().split(/[\s;,]+/).some(w => w.startsWith(q)))
            return 45;
        // Looser matches only once the query says enough.
        if (q.length < 3)
            return 0;
        if ((app.genericName + " " + app.keywords + " " + app.comment).toLowerCase().indexOf(q) >= 0)
            return 40;
        if (app.id.toLowerCase().indexOf(q) >= 0)
            return 30;
        let i = 0;
        for (const ch of name)
            if (ch === q[i])
                i++;
        return i === q.length ? 15 : 0;
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        const hidden = Config.values.launcher.hidden || [];
        const out = [];
        for (const app of Apps.all) {
            if (hidden.indexOf(app.id) >= 0)
                continue;
            const s = score(app, q);
            if (s > 0)
                out.push({
                    key: "app:" + app.id,
                    app: app,
                    title: app.name,
                    subtitle: app.genericName || app.comment,
                    icon: app.icon,
                    score: s,
                    run: () => Apps.launch(app)
                });
        }
        return out;
    }
}
