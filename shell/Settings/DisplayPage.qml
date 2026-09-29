import QtQuick
import qs.Compositor
import qs.Shared
import qs.Core
import qs.Components.Controls
import qs.Components.Text

// Displays: resolution, refresh rate, scale, position, VRR and HDR. Changes apply at
// once and revert after a countdown unless kept; kept settings are stored in
// Bifrost's config (displays.outputs) and written into bifrost.lua. The
// user's own Hyprland files are never touched. SDR saturation and HDR peak
// brightness are the exception: they apply live while their sliders move and
// are saved at once.
PageBase {
    id: page

    title: I18n.tr("Displays")

    property var outputs: []
    property var pending: null          // { previous, next }
    property int countdown: 0
    readonly property int revertSeconds: 15
    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]

    // Hyprland doesn't report max_luminance, so it comes from the saved
    // config; undefined means the EDID value is used.
    function savedPeak(name) {
        const o = (Config.get("displays.outputs") || {})[name];
        return o && o.maxLuminance !== undefined ? o.maxLuminance : undefined;
    }

    function load() {
        Compositor.queryOutputs(list => page.outputs = list.map(o => Object.assign({}, o, { maxLuminance: page.savedPeak(o.name) })));
    }

    function describe(o) {
        return o.width + " × " + o.height + " @ " + Math.round(o.refresh || o.refreshRate) + " Hz, " + I18n.tr("Scale") + " " + o.scale + " · " + (o.cm === "hdr" || o.cm === "hdredid" ? "HDR" : "SDR");
    }

    function apply(previous, next) {
        pending = { previous: previous, next: next };
        countdown = revertSeconds;
        Compositor.applyOutput(next);
        tick.restart();
    }

    function keep() {
        const saved = Object.assign({}, Config.get("displays.outputs") || {});
        const n = pending.next;
        saved[n.name] = Object.assign({}, saved[n.name] || {}, { width: n.width, height: n.height, refresh: n.refresh, x: n.x, y: n.y, scale: n.scale, vrr: n.vrr, bitdepth: n.bitdepth, cm: n.cm, sdrBrightness: n.sdrBrightness, sdrSaturation: n.sdrSaturation });
        if (n.maxLuminance !== undefined)
            saved[n.name].maxLuminance = n.maxLuminance;
        Config.set("displays.outputs", saved);
        Ctl.run(["hypr", "generate", "--write"], null, page);
        pending = null;
        tick.stop();
        load();
    }

    function revert() {
        if (pending)
            Compositor.applyOutput(pending.previous);
        pending = null;
        tick.stop();
        revertLoad.restart();
    }

    // Live sliders (SDR saturation, HDR peak brightness): output name →
    // { sdrSaturation?, maxLuminance? } not yet applied/saved.
    property var live: ({})

    function setLive(name, key, value) {
        const next = Object.assign({}, live);
        next[name] = Object.assign({}, live[name] || {});
        next[name][key] = value;
        live = next;
        if (!liveApply.running)
            liveApply.start();
        liveSave.restart();
    }

    // Each step starts from a fresh query of the output, so its other live
    // values (mode, HDR, SDR brightness) are carried over unchanged. Saving
    // stores that same live state, as the saved rule replaces the live one.
    function flushLive(save) {
        const wanted = live;
        Compositor.queryOutputs(list => {
            const saved = Object.assign({}, Config.get("displays.outputs") || {});
            let changed = false;
            list.forEach(o => {
                const w = wanted[o.name];
                if (w === undefined)
                    return;
                const peak = w.maxLuminance !== undefined ? w.maxLuminance : page.savedPeak(o.name);
                const next = { name: o.name, width: o.width, height: o.height, refresh: Math.round(o.refreshRate * 1000) / 1000, x: o.x, y: o.y, scale: o.scale, vrr: o.vrr, bitdepth: o.bitdepth, cm: o.cm, sdrBrightness: o.sdrBrightness, sdrSaturation: w.sdrSaturation !== undefined ? w.sdrSaturation : o.sdrSaturation };
                if (peak !== undefined)
                    next.maxLuminance = peak;
                if (Math.abs(o.sdrSaturation - next.sdrSaturation) > 0.001 || peak !== page.savedPeak(o.name))
                    Compositor.applyOutput(next);
                if (save) {
                    const entry = Object.assign({}, saved[o.name] || {}, next);
                    delete entry.name;
                    saved[o.name] = entry;
                    changed = true;
                }
            });
            if (!changed)
                return;
            Config.set("displays.outputs", saved);
            Ctl.run(["hypr", "generate", "--write"], null, page);
            const rest = Object.assign({}, page.live);
            for (const name in wanted)
                if (rest[name] === wanted[name])
                    delete rest[name];
            page.live = rest;
        });
    }

    Component.onCompleted: load()

    Timer {
        id: liveApply

        interval: 80
        onTriggered: page.flushLive(false)
    }

    Timer {
        id: liveSave

        interval: 700
        onTriggered: page.flushLive(true)
    }

    Timer {
        id: tick

        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown--;
            if (page.countdown <= 0)
                page.revert();
        }
    }

    Timer {
        id: revertLoad

        interval: 1500
        onTriggered: page.load()
    }

    BText {
        width: parent.width
        text: Compositor.supports("outputConfig") ? I18n.tr("Changes apply at once and are reverted after %1 seconds unless you choose Keep.").arg(page.revertSeconds) : I18n.tr("The compositor doesn't support display settings from Bifrost.")
        role: "caption"
        tone: "muted"
        wrapMode: Text.WordWrap
    }

    BrightnessControls { width: parent.width }

    // Keep / revert
    Card {
        visible: page.pending !== null

        BText {
            width: parent.width
            text: page.pending ? I18n.tr("Keep %1? Reverting in %2 s.").arg(page.describe(page.pending.next)).arg(page.countdown) : ""
            role: "label"
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: Theme.space.md

            BButton {
                text: I18n.tr("Keep")
                variant: "primary"
                onClicked: page.keep()
            }

            BButton {
                text: I18n.tr("Revert now")
                onClicked: page.revert()
            }
        }
    }

    Repeater {
        model: page.outputs

        delegate: Card {
            id: card

            required property var modelData
            readonly property var output: modelData
            property var draft: ({
                    name: output.name,
                    width: output.width,
                    height: output.height,
                    refresh: Math.round(output.refreshRate * 1000) / 1000,
                    x: output.x,
                    y: output.y,
                    scale: output.scale,
                    vrr: output.vrr,
                    bitdepth: output.bitdepth,
                    cm: output.cm,
                    sdrBrightness: output.sdrBrightness === undefined ? 1 : output.sdrBrightness,
                    sdrSaturation: output.sdrSaturation === undefined ? 1 : output.sdrSaturation,
                    maxLuminance: output.maxLuminance
                })
            readonly property var resolutions: {
                const seen = {};
                return output.modes.filter(m => {
                    const k = m.width + "x" + m.height;
                    return seen[k] ? false : (seen[k] = true);
                }).sort((a, b) => b.width * b.height - a.width * a.height);
            }
            readonly property var refreshes: output.modes.filter(m => m.width === draft.width && m.height === draft.height).map(m => m.refresh).sort((a, b) => b - a)
            readonly property bool changed: draft.width !== output.width || draft.height !== output.height || Math.abs(draft.refresh - output.refreshRate) > 0.5 || draft.scale !== output.scale || draft.x !== output.x || draft.y !== output.y || draft.vrr !== output.vrr || draft.bitdepth !== output.bitdepth || draft.cm !== output.cm || Math.abs(draft.sdrBrightness - (output.sdrBrightness === undefined ? 1 : output.sdrBrightness)) > 0.001

            function set(key, value) {
                const d = Object.assign({}, draft);
                d[key] = value;
                if (key === "hdr") {
                    d.cm = value ? "hdr" : "srgb";
                    d.bitdepth = value ? 10 : 8;
                    delete d.hdr;
                }
                if (key === "resolution") {
                    d.width = value.width;
                    d.height = value.height;
                    const r = output.modes.filter(m => m.width === value.width && m.height === value.height).map(m => m.refresh).sort((a, b) => b - a);
                    d.refresh = r.length ? r[0] : d.refresh;
                    delete d.resolution;
                }
                draft = d;
            }

            enabled: page.pending === null

            BText {
                text: card.output.name
                role: "heading"
            }

            BText {
                width: parent.width
                text: card.output.description + " · " + I18n.tr("now %1").arg(page.describe(card.output))
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            component Field: Item {
                id: field
                property string label: ""
                default property alias control: slot.data
                readonly property bool stacked: width < Theme.layout.editorWidth + Theme.control.height.md * 6
                width: parent.width
                height: stacked ? fieldLabel.implicitHeight + Theme.space.sm + slot.height : Math.max(fieldLabel.implicitHeight, slot.height)
                BText {
                    id: fieldLabel
                    width: field.stacked ? parent.width : Math.max(0, parent.width - slot.width - Theme.space.lg)
                    y: field.stacked ? 0 : (parent.height - height) / 2
                    text: field.label
                    role: "label"
                    wrapMode: Text.Wrap
                }
                Item {
                    id: slot
                    anchors.right: parent.right
                    y: field.stacked ? fieldLabel.height + Theme.space.sm : 0
                    width: Math.min(parent.width, Theme.layout.editorWidth)
                    height: Math.max(Theme.control.height.md, ...children.map(c => c.implicitHeight || 0))
                }
            }

            Field {
                label: I18n.tr("Resolution")

                BDropdown {
                    anchors.fill: parent
                    model: card.resolutions.map(m => ({ value: { width: m.width, height: m.height }, label: m.width + " × " + m.height }))
                    currentValue: ({ width: card.draft.width, height: card.draft.height })
                    onActivated: v => card.set("resolution", v)
                }
            }

            Field {
                label: I18n.tr("Refresh rate")

                BDropdown {
                    anchors.fill: parent
                    model: card.refreshes.map(r => ({ value: r, label: r.toFixed(r % 1 ? 2 : 0) + " Hz" }))
                    currentValue: card.refreshes.reduce((best, r) => Math.abs(r - card.draft.refresh) < Math.abs(best - card.draft.refresh) ? r : best, card.refreshes[0] || card.draft.refresh)
                    onActivated: v => card.set("refresh", v)
                }
            }

            Field {
                label: I18n.tr("Scale")

                BSegmented {
                    anchors.fill: parent
                    model: page.scales.map(s => s + "×")
                    currentIndex: page.scales.indexOf(card.draft.scale)
                    onActivated: i => card.set("scale", page.scales[i])
                }
            }

            Field {
                label: "Position (x, y)"

                Row {
                    anchors.fill: parent
                    spacing: Theme.space.sm

                    BTextField {
                        width: (parent.width - parent.spacing) / 2
                        text: String(card.draft.x)
                        onAccepted: t => card.set("x", Number(t) || 0)
                    }

                    BTextField {
                        width: (parent.width - parent.spacing) / 2
                        text: String(card.draft.y)
                        onAccepted: t => card.set("y", Number(t) || 0)
                    }
                }
            }

            Field {
                label: I18n.tr("Variable refresh rate (VRR)")

                BToggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: card.draft.vrr
                    onToggled: c => card.set("vrr", c)
                }
            }

            Field {
                label: I18n.tr("High dynamic range (HDR)")

                BToggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: card.draft.cm === "hdr" || card.draft.cm === "hdredid"
                    enabled: Compositor.supports("outputConfig")
                    onToggled: on => card.set("hdr", on)
                }
            }

            Field {
                label: I18n.tr("Brightness in HDR mode")
                enabled: card.draft.cm === "hdr" || card.draft.cm === "hdredid"
                BSlider {
                    anchors.left: parent.left
                    anchors.right: brightnessValue.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0.5
                    to: 15
                    stepSize: 0.05
                    value: card.draft.sdrBrightness
                    onMoved: v => card.set("sdrBrightness", v)
                }
                BText {
                    id: brightnessValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(card.draft.sdrBrightness * 100) + "%"
                    role: "mono"
                }
            }

            BText {
                width: parent.width
                text: I18n.tr("Adjusts desktop and SDR content brightness while HDR is enabled. 100% is the default.")
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            Field {
                label: I18n.tr("SDR Saturation")
                enabled: card.draft.cm === "hdr" || card.draft.cm === "hdredid"
                BSlider {
                    anchors.left: parent.left
                    anchors.right: saturationValue.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0.5
                    to: 2
                    stepSize: 0.05
                    value: card.draft.sdrSaturation
                    onMoved: v => {
                        card.set("sdrSaturation", Math.round(v * 100) / 100);
                        page.setLive(card.output.name, "sdrSaturation", Math.round(v * 100) / 100);
                    }
                }
                BText {
                    id: saturationValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Number(card.draft.sdrSaturation).toFixed(2)
                    role: "mono"
                }
            }

            BText {
                width: parent.width
                text: I18n.tr("Adjusts the colour saturation of desktop and SDR content while HDR is enabled. Applies and is saved at once; 1.00 is the default.")
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            Field {
                id: peakField
                readonly property int peak: card.draft.maxLuminance === undefined ? 1000 : card.draft.maxLuminance
                label: I18n.tr("HDR Peak Brightness")
                enabled: card.draft.cm === "hdr" || card.draft.cm === "hdredid"
                BSlider {
                    anchors.left: parent.left
                    anchors.right: peakValue.left
                    anchors.rightMargin: Theme.space.md
                    anchors.verticalCenter: parent.verticalCenter
                    from: 400
                    to: 1500
                    stepSize: 50
                    value: peakField.peak
                    onMoved: v => {
                        const nits = Math.round(v / 50) * 50;
                        card.set("maxLuminance", nits);
                        page.setLive(card.output.name, "maxLuminance", nits);
                    }
                }
                BText {
                    id: peakValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("%1 nits").arg(peakField.peak)
                    role: "mono"
                }
            }

            BText {
                width: parent.width
                text: I18n.tr("The display's maximum luminance, used by Hyprland for HDR tone mapping. Overrides the value the display reports; applies and is saved at once.")
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            BText {
                width: parent.width
                text: I18n.tr("Requires an HDR-capable display. Choose Apply to test, then Keep to save.")
                role: "caption"
                tone: "muted"
                wrapMode: Text.WordWrap
            }

            Row {
                spacing: Theme.space.md

                BButton {
                    text: I18n.tr("Apply")
                    variant: "primary"
                    enabled: card.changed && Compositor.supports("outputConfig")
                    onClicked: page.apply({
                        name: card.output.name,
                        width: card.output.width,
                        height: card.output.height,
                        refresh: card.output.refreshRate,
                        x: card.output.x,
                        y: card.output.y,
                        scale: card.output.scale,
                        vrr: card.output.vrr,
                        bitdepth: card.output.bitdepth,
                        cm: card.output.cm,
                        sdrBrightness: card.output.sdrBrightness === undefined ? 1 : card.output.sdrBrightness,
                        // Saturation and peak are live already: reverting keeps them.
                        sdrSaturation: card.draft.sdrSaturation,
                        maxLuminance: card.draft.maxLuminance
                    }, card.draft)
                }

                BButton {
                    text: I18n.tr("Undo")
                    variant: "ghost"
                    enabled: card.changed
                    onClicked: page.load()
                }
            }
        }
    }
}
