.pragma library

// Pure helpers for the login screen (shell/greeter.qml); tested by the selftest.

// "@@<path>" + file text blocks (see greeter.qml) → sessions to offer:
// [{ id, name, exec, desktopNames }] sorted by name, hidden ones left out.
function parseSessions(text) {
    const out = [];
    for (const block of String(text || "").split("@@").slice(1)) {
        const nl = block.indexOf("\n");
        const path = block.slice(0, nl).trim();
        const fields = {};
        let inEntry = false;
        for (const raw of block.slice(nl + 1).split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                inEntry = line === "[Desktop Entry]";
                continue;
            }
            const eq = line.indexOf("=");
            if (inEntry && eq > 0 && !(line.slice(0, eq) in fields))
                fields[line.slice(0, eq)] = line.slice(eq + 1);
        }
        if (!fields.Exec || fields.Hidden === "true" || fields.NoDisplay === "true")
            continue;
        out.push({
            id: path.split("/").pop().replace(/\.desktop$/, ""),
            name: fields.Name || path,
            exec: fields.Exec,
            desktopNames: fields.DesktopNames || ""
        });
    }
    return out.sort((a, b) => a.name.localeCompare(b.name));
}

// /etc/passwd → people who can log in: [{ name, realName }].
function parseUsers(passwd) {
    const out = [];
    for (const line of String(passwd || "").split("\n")) {
        const f = line.split(":");
        if (f.length < 7)
            continue;
        const uid = Number(f[2]);
        if (uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(f[6]))
            continue;
        out.push({ name: f[0], realName: f[4].split(",")[0] });
    }
    return out;
}

// A desktop file's Exec as an argument list (quotes kept together, field codes dropped).
function commandOf(exec) {
    const args = [];
    let cur = "", quote = "", any = false;
    for (const c of String(exec || "")) {
        if (quote) {
            if (c === quote)
                quote = "";
            else
                cur += c;
        } else if (c === '"' || c === "'") {
            quote = c;
            any = true;
        } else if (c === " " || c === "\t") {
            if (cur !== "" || any)
                args.push(cur);
            cur = "";
            any = false;
        } else {
            cur += c;
        }
    }
    if (cur !== "" || any)
        args.push(cur);
    return args.filter(a => !/^%[fFuUdDnNickvm]$/.test(a));
}

// Environment a session starts with.
function sessionEnv(session) {
    const desktops = session.desktopNames ? session.desktopNames.replace(/;$/, "").replace(/;/g, ":") : session.id;
    return ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + session.id, "XDG_CURRENT_DESKTOP=" + desktops];
}

function initials(user) {
    const words = String((user && (user.realName || user.name)) || "?").trim().split(/\s+/);
    return (words[0][0] + (words.length > 1 ? words[words.length - 1][0] : "")).toUpperCase();
}
