import QtQuick
import qs.Compositor
import qs.Core
import qs.Components.Controls
import qs.Components.Text
import qs.Services

// Display menu: HDR on/off per output. Turning HDR on applies at once and
// reverts after a countdown unless kept (in case the picture is unusable);
// kept choices go to displays.outputs and bifrost.lua.
StatusMenu {
    id: menu

    title: I18n.tr("Display")

    property var outputs: []
    property var pending: null        // { previous, next }
    property int countdown: 0
    readonly property int revertSeconds: 15

    function load() {
        Compositor.queryOutputs(list => menu.outputs = list);
    }

    function current(o) {
        return { name: o.name, width: o.width, height: o.height, refresh: o.refreshRate, x: o.x, y: o.y, scale: o.scale, vrr: o.vrr, bitdepth: o.bitdepth, cm: o.cm, sdrBrightness: o.sdrBrightness, sdrSaturation: o.sdrSaturation };
    }

    function setHdr(o, on) {
        const prev = current(o);
        const next = Object.assign({}, prev, { cm: on ? "hdr" : (prev.cm === "hdr" ? "srgb" : prev.cm) });
        Compositor.applyOutput(next);
        if (on) {
            pending = { previous: prev, next: next };
            countdown = revertSeconds;
            tick.restart();
        } else {
            save(next);
        }
        reload.restart();
    }

    function save(o) {
        const saved = Object.assign({}, Config.get("displays.outputs") || {});
        saved[o.name] = Object.assign({}, saved[o.name] || {}, { width: o.width, height: o.height, refresh: o.refresh, x: o.x, y: o.y, scale: o.scale, vrr: o.vrr, bitdepth: o.bitdepth, cm: o.cm, sdrBrightness: o.sdrBrightness, sdrSaturation: o.sdrSaturation });
        Config.set("displays.outputs", saved);
        Ctl.run(["hypr", "generate", "--write"], null, menu);
    }

    function keep() {
        save(pending.next);
        pending = null;
        tick.stop();
    }

    function revert() {
        if (pending)
            Compositor.applyOutput(pending.previous);
        pending = null;
        tick.stop();
        reload.restart();
    }

    onVisibleChanged: if (visible)
        load()

    Timer {
        id: tick

        interval: 1000
        repeat: true
        onTriggered: {
            menu.countdown--;
            if (menu.countdown <= 0)
                menu.revert();
        }
    }

    Timer {
        id: reload

        interval: 1200
        onTriggered: menu.load()
    }

    Repeater {
        model: menu.outputs

        delegate: BListRow {
            id: row

            required property var modelData

            width: parent.width
            icon: "display"
            title: "HDR" + (menu.outputs.length > 1 ? " · " + modelData.name : "")
            subtitle: modelData.description.split(" ").slice(0, 3).join(" ") + " · " + (modelData.cm === "hdr" || modelData.cm === "hdredid" ? "HDR" : "SDR (" + modelData.cm + ")")
            interactive: false
            enabled: menu.pending === null && Compositor.supports("outputConfig")

            BToggle {
                checked: row.modelData.cm === "hdr" || row.modelData.cm === "hdredid"
                onToggled: c => menu.setHdr(row.modelData, c)
            }
        }
    }

    Column {
        visible: menu.pending !== null
        width: parent.width
        spacing: Theme.space.sm

        BText {
            width: parent.width
            text: I18n.tr("Keep HDR? Reverting in %1 s.").arg(menu.countdown)
            role: "label"
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: Theme.space.sm

            BButton {
                text: I18n.tr("Keep")
                variant: "primary"
                size: "sm"
                onClicked: menu.keep()
            }

            BButton {
                text: I18n.tr("Revert now")
                size: "sm"
                onClicked: menu.revert()
            }
        }
    }

    BButton {
        size: "sm"
        variant: "ghost"
        icon: "settings"
        text: I18n.tr("Display settings")
        onClicked: {
            menu.close();
            Launch.openSettings("monitors");
        }
    }
}
