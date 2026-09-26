pragma Singleton

import QtQuick
import Quickshell
import qs.Core

// Navigation state of the Settings app.
Singleton {
    id: nav

    property string page: ""          // section id or custom page id
    property string query: ""
    property string highlightKey: ""

    // Opens a section, a custom page, or the section of a setting key (and
    // briefly highlights that setting).
    function open(target: string) {
        if (!target)
            return;
        query = "";
        const d = Schema.def(target);
        if (d) {
            page = d.section;
            highlightKey = target;
            highlightTimer.restart();
        } else {
            page = target;
        }
    }

    function firstPage(): string {
        for (const c of Schema.categories)
            for (const s of Schema.sectionsInCategory(c.id))
                if (Schema.isSectionSupported(s.id))
                    return s.id;
        return "data";
    }

    function pageInfo(id: string): var {
        for (const section of Schema.sections)
            for (const p of section.subpages || [])
                if (p.id === id) return {kind:"page", id:id, label:p.label, icon:p.icon, page:p.page};
        const s = Schema.section(id);
        if (s && !s.hidden)
            return s.page ? { kind: "page", id: id, label: s.label, icon: s.icon, page: s.page } : { kind: "section", id: id, label: s.label, icon: s.icon };
        for (const c of Schema.categories)
            for (const p of c.pages || [])
                if (p.id === id)
                    return { kind: "page", id: id, label: p.label, icon: p.icon, page: p.page };
        return null;
    }

    Timer {
        id: highlightTimer

        interval: 1800
        onTriggered: nav.highlightKey = ""
    }
}
