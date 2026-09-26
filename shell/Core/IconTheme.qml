pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// Which icon theme Bifrost's app icons come from (dock, launcher, system
// menu, notifications, recent files, tray). appearance.icons.theme:
//   empty    – Bifrost default: Gruvbox-Plus-Dark-IceBlue-FullBlue
//              (the system theme if FullBlue isn't installed)
//   "system" – whatever the desktop uses; Bifrost doesn't pick one
//   a name   – that theme
// The choice is resolved by bifrostctl (one implementation, also used for
// QS_ICON_THEME at start) and switched live by loading its lookup index.
Singleton {
    id: root

    readonly property var choice: ((Config.values.appearance || {}).icons || {}).theme || null
    readonly property string variant: Theme.variant
    readonly property string theme: IconLookup.theme
    property string source: ""       // default | system | custom | missing | default-missing

    function refresh() {
        Ctl.run(["icons", "effective", "--variant", variant, "--json"], (ok, out, data) => {
            if (!ok || !data)
                return;
            root.source = data.source;
            if (data.theme === IconLookup.theme)
                return;
            Ctl.run(["icons", "index", data.theme, "--json"], (ok2, out2, idx) => {
                if (!ok2 || !idx) {
                    console.warn("[bifrost] icon theme", data.theme, "could not be indexed:", out2);
                    return;
                }
                const res = reader.read(idx.file);
                if (!res.ok)
                    return;
                IconLookup.icons = res.data.icons || {};
                IconLookup.theme = data.theme;
                console.info("[bifrost] icon theme:", data.theme, "(" + data.source + ",", Object.keys(IconLookup.icons).length, "icons)");
            }, root);
        }, root);
    }

    onChoiceChanged: refreshLater.restart()
    onVariantChanged: refreshLater.restart()

    Timer {
        id: refreshLater

        interval: 50
        onTriggered: root.refresh()
    }

    JsonReader {
        id: reader
    }

    Component.onCompleted: refreshLater.restart()
}
