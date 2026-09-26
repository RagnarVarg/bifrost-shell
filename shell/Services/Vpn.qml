pragma Singleton

import QtQuick
import Quickshell
import qs.Compat

// VPN status/toggle. Providers (only this file knows them):
//   pia – Private Internet Access (piactl)
//   nm  – NetworkManager VPN/WireGuard connections (nmcli)
// The state follows the provider's own monitor (`piactl monitor
// connectionstate`, `nmcli monitor`), so the bar icon changes at once; while
// retained (a menu is open) it also polls, for the region and as a fallback.
Singleton {
    id: root

    property int users: 0
    property string provider: ""
    readonly property bool available: provider !== ""
    property bool connected: false
    property bool busy: false
    property string detail: ""
    property string nmConnection: ""

    function retain() {
        users++;
        refresh();
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    // off | connecting | on (connecting also covers disconnecting).
    readonly property string phase: busy ? "connecting" : connected ? "on" : "off"

    // piactl connection states: Disconnected, Connecting, StillConnecting,
    // Connected, Interrupted, Reconnecting, StillReconnecting,
    // DisconnectingToReconnect, Disconnecting.
    function applyPia(state) {
        state = state.trim();
        if (!state)
            return;
        connected = state === "Connected";
        busy = /Connecting|Reconnecting|Disconnecting|Interrupted/.test(state);
        Exec.runOptional(["piactl", "get", "region"], (c, r) => root.detail = c === 0 ? "PIA · " + r.trim() : "PIA");
    }

    function refresh() {
        if (provider === "" || provider === "pia") {
            Exec.runOptional(["piactl", "get", "connectionstate"], (code, out) => {
                if (code === 0) {
                    provider = "pia";
                    applyPia(out);
                } else if (provider === "") {
                    refreshNm();
                }
            }, 4000);
        } else {
            refreshNm();
        }
    }

    function refreshNm() {
        const vpns = NetworkStatus.profiles.filter(p => p.type === "vpn" || p.type === "wireguard");
        if (!vpns.length) {
            if (provider === "nm") { provider = ""; connected = false; busy = false; nmConnection = ""; }
            return;
        }
        provider = "nm";
        const active = vpns.find(p => p.active);
        const changing = vpns.find(p => p.state === "activating" || p.state === "deactivating");
        const selected = active || changing || vpns[0];
        connected = !!active; busy = !!changing;
        nmConnection = selected.uuid;
        detail = selected.name;
    }

    Connections {
        target: NetworkStatus
        function onProfilesChanged() { if (root.provider !== "pia") root.refreshNm(); }
    }

    function toggle() {
        if (!provider || busy || (provider === "nm" && NetworkStatus.managementBusy)) return;
        busy = true;
        if (provider === "pia")
            Exec.runOptional(["piactl", connected ? "disconnect" : "connect"], () => root.refresh());
        else if (provider === "nm")
            NetworkStatus.manage(["connection", connected ? "down" : "up", "uuid", nmConnection], () => root.refresh());
    }

    LineWatcher {
        active: root.provider === "pia"
        command: ["piactl", "monitor", "connectionstate"]
        onLine: text => root.applyPia(text)
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.users > 0
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
