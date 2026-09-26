pragma Singleton

import QtQuick
import qs.Compat
import qs.Core
import Quickshell
import Quickshell.Networking

// Network state and Wi-Fi control from Quickshell.Networking (NetworkManager
// over D-Bus). Everything is read from NetworkManager's own objects, so
// changes made elsewhere (nmcli, another applet, a network going away) show
// at once; actions (Wi-Fi on/off, connect, disconnect, forget) go to
// NetworkManager, never only to the UI.
// Scanning runs only while a network list is shown (retainScan/releaseScan).
Singleton {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) || null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wifiNetwork: wifiDevice && wifiDevice.networks ? (wifiDevice.networks.values.find(n => n.connected) || null) : null
    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    // Rfkill hardware switch (off: Wi-Fi can't be turned on from here).
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled
    readonly property bool connected: wired !== null || wifiNetwork !== null
    readonly property string kind: wired ? "wired" : wifiNetwork ? "wifi" : "none"
    readonly property string label: wired ? I18n.tr("Wired") : wifiNetwork ? wifiNetwork.name : (hasWifi && !wifiEnabled ? I18n.tr("Wi-Fi off") : I18n.tr("Disconnected"))
    readonly property real signal: wifiNetwork ? wifiNetwork.signalStrength : 0
    // NetworkManager's own internet check: "full" | "limited" | "portal" |
    // "none" | "unknown".
    readonly property string internet: !Networking.canCheckConnectivity ? "unknown" : ({
            [NetworkConnectivity.Full]: "full",
            [NetworkConnectivity.Limited]: "limited",
            [NetworkConnectivity.Portal]: "portal",
            [NetworkConnectivity.None]: "none"
        })[Networking.connectivity] || "unknown"

    // Wi-Fi networks in view: connected first, then saved ones, then by
    // signal. Networks without a name (hidden SSIDs) are left out.
    readonly property var networks: {
        const list = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.filter(n => n.name) : [];
        return list.slice().sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength) || a.name.localeCompare(b.name));
    }

    // Per network name: the last failure ("" none) and whether we are
    // waiting for it to connect.
    property var failures: ({})
    property string pending: ""

    function setWifiEnabled(on: bool) {
        Networking.wifiEnabled = on;
    }

    // "open" (no password), "psk" (a passphrase: WPA/WPA2/WPA3 personal,
    // WEP) or "enterprise" (needs certificates/accounts: Settings, later).
    function securityOf(n): string {
        if (!n)
            return "open";
        switch (n.security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "open";
        case WifiSecurityType.Wpa2Eap:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Leap:
        case WifiSecurityType.Wpa3SuiteB192:
            return "enterprise";
        default:
            return "psk";
        }
    }

    function signalIcon(strength: real): string {
        return strength >= 0.67 ? "wifi" : strength >= 0.34 ? "wifi-2" : "wifi-1";
    }

    // A saved or open network connects directly; a new protected one needs
    // its passphrase (connectWithPsk).
    function needsPassword(n): bool {
        return n && !n.known && securityOf(n) === "psk";
    }

    function clearFailure(name: string) {
        if (failures[name] === undefined)
            return;
        const f = Object.assign({}, failures);
        delete f[name];
        failures = f;
    }

    function connectTo(n) {
        if (!n)
            return;
        clearFailure(n.name);
        pending = n.name;
        n.connect();
    }

    function connectWithPassword(n, psk: string) {
        if (!n)
            return;
        clearFailure(n.name);
        pending = n.name;
        n.connectWithPsk(psk);
    }

    function disconnectFrom(n) {
        if (n)
            n.disconnect();
    }

    function forget(n) {
        if (!n)
            return;
        clearFailure(n.name);
        n.forget();
    }

    function failureText(reason): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return I18n.tr("Wrong or missing password");
        case ConnectionFailReason.WifiAuthTimeout:
            return I18n.tr("No answer from the network");
        case ConnectionFailReason.WifiNetworkLost:
            return I18n.tr("Network lost");
        default:
            return I18n.tr("Could not connect");
        }
    }

    // Failures come per network object; watch the ones in view.
    Instantiator {
        model: root.networks

        delegate: Connections {
            required property var modelData

            target: modelData

            function onConnectionFailed(reason) {
                const f = Object.assign({}, root.failures);
                f[modelData.name] = root.failureText(reason);
                root.failures = f;
                if (root.pending === modelData.name)
                    root.pending = "";
            }

            function onConnectedChanged() {
                if (modelData.connected) {
                    root.clearFailure(modelData.name);
                    if (root.pending === modelData.name)
                        root.pending = "";
                }
            }
        }
    }

    // Full management extends this same NetworkManager service. nmcli is
    // only an adapter for profile properties not exposed by Quickshell.
    property var profiles: []
    property var interfaces: []
    property string detailInterface: ""
    property bool connectionEditorAvailable: false
    property bool hiddenNetworkAvailable: false
    property var details: ({})
    property var profileDetails: ({})
    property string detailProfile: ""
    property string managementError: ""
    property bool managementBusy: false
    property bool refreshBusy: false
    readonly property var editableProperties: ["connection.autoconnect", "connection.autoconnect-priority", "connection.metered", "ipv4.method", "ipv4.addresses", "ipv4.gateway", "ipv4.dns", "ipv4.dns-search", "ipv4.routes", "ipv6.method", "ipv6.addresses", "ipv6.gateway", "ipv6.dns", "ipv6.dns-search", "ipv6.routes", "proxy.method", "proxy.pac-url"]

    function fields(line) {
        const out = []; let value = "", escaped = false;
        for (const c of line) {
            if (escaped) { value += c; escaped = false; }
            else if (c === "\\") escaped = true;
            else if (c === ":") { out.push(value); value = ""; }
            else value += c;
        }
        out.push(value); return out;
    }
    function properties(text) {
        const result = {};
        for (const line of text.trim().split("\n")) {
            const i = line.indexOf(":");
            if (i >= 0) result[line.slice(0, i)] = line.slice(i + 1);
        }
        return result;
    }
    function refreshManagement() {
        if (refreshBusy) { managementRefresh.restart(); return; }
        refreshBusy = true;
        Exec.run(["env", "LC_ALL=C", "nmcli", "-t", "-f", "UUID,NAME,TYPE,DEVICE,STATE", "connection", "show"], (code, out) => {
            if (code === 0) profiles = out.trim().split("\n").filter(Boolean).map(line => {
                const f = fields(line); return { uuid: f[0], name: f[1], type: f[2], device: f[3], state: f[4], active: f[4] === "activated" };
            });
            Exec.run(["env", "LC_ALL=C", "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"], (code2, out2) => {
                if (code2 === 0) interfaces = out2.trim().split("\n").filter(Boolean).map(line => {
                    const f = fields(line); return { name: f[0], type: f[1], state: f[2], connection: f[3] };
                });
                refreshBusy = false;
                if (detailInterface) readDetails(detailInterface);
            }, 5000, root);
        }, 5000, root);
    }
    function manage(args, done) {
        if (managementBusy) return;
        managementBusy = true; managementError = "";
        Exec.run(["env", "LC_ALL=C", "nmcli", "--wait", "15"].concat(args), (code, out, err) => {
            managementBusy = false;
            managementError = code === 0 ? "" : (err.trim() || I18n.tr("Network operation failed"));
            refreshManagement();
            if (done) done(code === 0);
        }, 20000, root);
    }
    function activateProfile(uuid: string) { manage(["connection", "up", "uuid", uuid]); }
    function deactivateProfile(uuid: string) { manage(["connection", "down", "uuid", uuid]); }
    function deleteProfile(uuid: string) { manage(["connection", "delete", "uuid", uuid]); }
    function setDeviceEnabled(name: string, on: bool) { manage(["device", on ? "connect" : "disconnect", name]); }
    function rescan() { if (hasWifi) manage(["device", "wifi", "rescan"]); }
    function readDetails(name: string) {
        detailInterface = name;
        Exec.run(["env", "LC_ALL=C", "nmcli", "-t", "--escape", "no", "-f", "GENERAL,IP4,IP6,WIRED-PROPERTIES", "device", "show", name], (code, out) => {
            if (code === 0 && name === detailInterface) details = properties(out);
        }, 5000, root);
    }
    function readProfile(uuid: string) {
        detailProfile = uuid;
        profileDetails = {};
        Exec.run(["env", "LC_ALL=C", "nmcli", "-t", "--escape", "no", "-f", editableProperties.join(","), "connection", "show", "uuid", uuid], (code, out, err) => {
            if (uuid !== detailProfile) return;
            if (code === 0) profileDetails = properties(out);
            else managementError = err.trim();
        }, 5000, root);
    }
    function saveProfile(uuid: string, values) {
        const args = ["connection", "modify", "uuid", uuid];
        for (const key of editableProperties)
            if (values[key] !== undefined) args.push(key, String(values[key]));
        manage(args);
    }
    // Native scanner still handles visible Wi-Fi lists. This event stream
    // serves profiles/details and VPN consumers, avoiding a second VPN watcher.
    LineWatcher {
        command: ["nmcli", "monitor"]
        onLine: managementRefresh.restart()
    }
    Timer { id: managementRefresh; interval: 300; onTriggered: root.refreshManagement() }
    function connectHidden(ssid: string, password: string, iface: string) {
        if (managementBusy || !hiddenNetworkAvailable) return;
        managementBusy = true; managementError = "";
        Exec.run(["python3", Paths.repoDir + "/tools/network_hidden.py"], (code) => {
            managementBusy = false;
            managementError = code === 0 ? "" : I18n.tr("Could not connect to hidden network");
            refreshManagement();
        }, 20000, root, JSON.stringify({ ssid: ssid, password: password, interface: iface }) + "\n");
    }
    function openConnectionEditor(type: string) {
        if (connectionEditorAvailable) Platform.launch(["nm-connection-editor", "--create", "--type", type]);
    }
    Component.onCompleted: {
        refreshManagement();
        Exec.run(["python3", "-c", "from gi.repository import Gio, GLib"], code => hiddenNetworkAvailable = code === 0);
        Exec.run(["sh", "-c", "command -v nm-connection-editor"], (code) => connectionEditorAvailable = code === 0);
    }

    // ── Scanning while a list is shown ─────────────────────────────────
    property int scanUsers: 0

    function retainScan() {
        scanUsers++;
    }

    function releaseScan() {
        scanUsers = Math.max(0, scanUsers - 1);
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.scanUsers > 0 && root.wifiEnabled
        when: root.wifiDevice !== null
    }
}
