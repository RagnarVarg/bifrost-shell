pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Recently used files and folders from the freedesktop list
// (~/.local/share/recently-used.xbel, written by GTK apps and file managers).
// Read-only: Bifrost never writes the list. Entries whose file is gone are
// left out. refresh() re-reads; items: [{ path, name, mime, icon, modified }]
Singleton {
    id: recent

    property var items: []
    property int limit: 10
    readonly property string file: (Platform.env("XDG_DATA_HOME") || Platform.expandHome("~/.local/share")) + "/recently-used.xbel"

    function decodeEntities(s) {
        return s.replace(/&apos;/g, "'").replace(/&quot;/g, "\"").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
    }

    function parse(xml) {
        const out = [];
        const re = /<bookmark\s+([^>]*)>([\s\S]*?)<\/bookmark>/g;
        let m;
        while ((m = re.exec(xml)) !== null) {
            const attrs = m[1];
            const href = (attrs.match(/href="([^"]*)"/) || [])[1] || "";
            if (!href.startsWith("file://"))
                continue;
            let path;
            try {
                path = decodeURIComponent(decodeEntities(href).slice(7));
            } catch (e) {
                continue;
            }
            const modified = (attrs.match(/modified="([^"]*)"/) || [])[1] || (attrs.match(/visited="([^"]*)"/) || [])[1] || "";
            const mime = (m[2].match(/mime-type\s+type="([^"]*)"/) || [])[1] || "";
            out.push({
                path: path,
                name: path.slice(path.lastIndexOf("/") + 1) || path,
                mime: mime,
                icon: Platform.iconPath(mime === "inode/directory" ? "folder" : mime.replace("/", "-"), "text-x-generic"),
                modified: modified
            });
        }
        out.sort((a, b) => a.modified < b.modified ? 1 : a.modified > b.modified ? -1 : 0);
        return out;
    }

    function refresh() {
        const text = reader.readFresh();
        const all = text ? parse(text) : [];
        const seen = {};
        const unique = all.filter(i => !seen[i.path] && (seen[i.path] = true)).slice(0, limit * 3);
        if (!unique.length) {
            items = [];
            return;
        }
        // Keep only entries that still exist.
        Exec.run(["sh", "-c", "for f; do [ -e \"$f\" ] && printf '%s\\n' \"$f\"; done", "sh"].concat(unique.map(i => i.path)), (code, out) => {
            const exists = {};
            for (const line of out.split("\n"))
                exists[line] = true;
            recent.items = unique.filter(i => exists[i.path]).slice(0, recent.limit);
        });
    }

    function open(item) {
        if (item)
            Platform.launch(["xdg-open", item.path]);
    }

    WatchedFile {
        id: reader

        path: recent.file
        watch: false
    }
}
