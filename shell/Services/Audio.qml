pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Compat
import qs.Core

// Audio via PipeWire (Quickshell): default output/input, their volume and
// mute, the hardware devices to choose from, and Bluetooth card profiles.
// Choosing a device sets the system's configured default (PipeWire
// "default.configured.audio.sink/source", which WirePlumber follows), so the
// choice holds for every app and outside Bifrost; changes made elsewhere
// (pavucontrol, wpctl, plugging in) show here at once, as everything is read
// from PipeWire's own objects. Volume is 0..1 (PipeWire allows more; the UI
// clamps to 1). `changed` fires on user-visible changes after startup, which
// drives the OSD.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: sink !== null && sink.audio !== null
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property bool micAvailable: source !== null && source.audio !== null
    readonly property real micVolume: micAvailable ? source.audio.volume : 0
    readonly property bool micMuted: micAvailable ? source.audio.muted : false
    readonly property string sinkName: available ? (sink.description || sink.nickname || sink.name) : ""

    // Hardware outputs and inputs (not application streams).
    readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio) : []
    readonly property var sources: Pipewire.nodes ? Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && String((n.properties || {})["media.class"] || "Audio/Source").indexOf("Audio/Source") === 0) : []

    function nameOf(node): string {
        return node ? (node.description || node.nickname || node.name) : "";
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    // What kind of device a node is, for its icon and label:
    // "bluetooth" | "headphones" | "display" | "digital" | "speaker" | "mic".
    function kindOf(node): string {
        if (!node)
            return "";
        const n = String(node.name || "").toLowerCase();
        const props = node.properties || {};
        const form = String(props["device.form-factor"] || "").toLowerCase();
        if (n.indexOf("bluez") === 0 || props["device.api"] === "bluez5")
            return "bluetooth";
        if (form === "headphone" || form === "headset" || n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0)
            return "headphones";
        if (!node.isSink)
            return "mic";
        if (n.indexOf("hdmi") >= 0 || n.indexOf("displayport") >= 0 || n.indexOf("-dp") >= 0)
            return "display";
        if (n.indexOf("iec958") >= 0 || n.indexOf("spdif") >= 0)
            return "digital";
        return "speaker";
    }

    function iconOf(node): string {
        return ({
                bluetooth: "headphones",
                headphones: "headphones",
                display: "display",
                digital: "speaker",
                speaker: "speaker",
                mic: "mic"
            })[kindOf(node)] || "volume";
    }

    function toggleNodeMute(node) {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
    }

    // ── Bluetooth card profiles (pactl, the PulseAudio interface of
    // PipeWire) ─ e.g. AirPods: "a2dp-sink" (music quality, no microphone)
    // or "headset-head-unit" (with microphone). [{ card, name, device,
    // active, profiles: [{ id, label, available }] }]
    property var btCards: []

    function refreshCards() {
        Exec.run(["pactl", "-f", "json", "list", "cards"], (code, out) => {
            if (code !== 0)
                return;
            try {
                root.btCards = root.parseCards(out);
            } catch (e) {
                root.btCards = [];
            }
        }, 4000);
    }

    function parseCards(json: string): var {
        return JSON.parse(json).filter(c => (c.properties || {})["device.api"] === "bluez5").map(c => ({
                    card: c.name,
                    name: (c.properties || {})["device.description"] || c.name,
                    device: String((c.properties || {})["device.string"] || ""),
                    active: c.active_profile,
                    profiles: Object.keys(c.profiles || {}).filter(p => p !== "off").map(p => ({
                                id: p,
                                label: c.profiles[p].description || p,
                                available: c.profiles[p].available !== false
                            }))
                }));
    }

    // A card's profiles as two understandable choices: music (A2DP, best
    // variant) and headset with microphone (HFP/HSP). [{ id, label, kind }],
    // and which of them is active.
    function profileChoices(card): var {
        if (!card)
            return [];
        const avail = card.profiles.filter(p => p.available).map(p => p.id);
        const pick = (exact, prefix) => avail.indexOf(exact) >= 0 ? exact : (avail.find(id => id.indexOf(prefix) === 0) || "");
        const out = [];
        const music = pick("a2dp-sink", "a2dp");
        const headset = pick("headset-head-unit", "headset");
        if (music)
            out.push({ id: music, kind: "music", label: I18n.tr("Music") });
        if (headset)
            out.push({ id: headset, kind: "headset", label: I18n.tr("Headset + mic") });
        return out;
    }

    function activeChoice(card): string {
        const a = card ? String(card.active) : "";
        return a.indexOf("a2dp") === 0 ? "music" : a.indexOf("headset") === 0 ? "headset" : "";
    }

    function setCardProfile(card: string, profile: string) {
        Exec.run(["pactl", "set-card-profile", card, profile], () => root.refreshCards(), 4000);
    }

    // The Bluetooth card a node belongs to (its node name carries the address).
    function cardOf(node): var {
        if (!node)
            return null;
        const n = String(node.name || "");
        return btCards.find(c => {
            const addr = c.card.replace(/^bluez_card\./, "");
            return addr && n.indexOf(addr) >= 0;
        }) || null;
    }

    // Devices come and go (Bluetooth, USB): re-read the card profiles.
    readonly property int deviceCount: sinks.length + sources.length
    onDeviceCountChanged: cardsSettle.restart()

    Timer {
        id: cardsSettle

        interval: 400
        onTriggered: root.refreshCards()
    }

    Component.onCompleted: refreshCards()

    property bool settled: false

    signal changed

    function setVolume(v: real) {
        if (available) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function adjust(delta: real) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(v: real) {
        if (micAvailable)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMicMute() {
        if (micAvailable)
            source.audio.muted = !source.audio.muted;
    }

    onVolumeChanged: if (settled)
        changed()
    onMutedChanged: if (settled)
        changed()

    // Bound nodes report properties, volume and mute: the defaults always,
    // every device while a device list is shown (retain/release).
    property int listUsers: 0

    function retainDevices() {
        listUsers++;
        refreshCards();
    }

    function releaseDevices() {
        listUsers = Math.max(0, listUsers - 1);
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n !== null).concat(root.listUsers > 0 ? root.sinks.concat(root.sources) : [])
    }

    // Ignore the initial values reported while PipeWire binds.
    Timer {
        interval: 1500
        running: true
        onTriggered: root.settled = true
    }
}
