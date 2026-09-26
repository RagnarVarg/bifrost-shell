#!/usr/bin/env python3
"""Bluetooth pairing agent for the Bifrost shell (BlueZ org.bluez.Agent1).

Quickshell's Bluetooth module can start pairing but registers no agent, so a
device that must show or confirm a code (keyboards, phones) could not pair.
This registers the session's default agent and talks to the shell in JSON
lines:

  stdout  {"event": "ready"}
          {"event": "request", "id": 1, "kind": KIND, "device": PATH,
           "name": NAME, "passkey": "012345" | null, "entered": N | null}
          {"event": "update", "id": 1, "entered": N}  digits typed on the device
          {"event": "done", "id": 1}                the device is now paired
          {"event": "cancel", "id": 1}              BlueZ gave up (timeout)
          {"event": "error", "message": TEXT}       could not register
  stdin   {"id": 1, "accept": true, "value": "1234"}

KIND: confirm (numeric comparison), authorize (pairing without a code),
service (a new device wants a service), display (type the shown code on the
device; accept = dismiss), pin / passkey (enter the code the device shows).
Requests from paired, trusted devices for a service are allowed at once.
Needs python-gobject (optional dependency); exits when stdin closes.
"""
import json
import sys
import warnings

# Gio.DBusConnection.register_object works on every PyGObject we support.
warnings.filterwarnings("ignore", category=DeprecationWarning)

AGENT_PATH = "/org/bifrost/bluetooth/agent"
CAPABILITY = "KeyboardDisplay"
REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"

INTROSPECTION = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
    <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
    <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
    <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
    <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
    <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="Cancel"/>
  </interface>
</node>
"""


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def parse_reply(line):
    """A reply line from the shell → (id, accept, value) or None."""
    try:
        data = json.loads(line)
        return int(data["id"]), data.get("accept") is True, str(data.get("value", ""))
    except (ValueError, KeyError, TypeError):
        return None


def reply_value(kind, value):
    """What BlueZ gets back for an accepted request of this kind."""
    if kind == "pin":
        if not 1 <= len(value) <= 16:
            raise ValueError("PIN must be 1–16 characters")
        return ("(s)", (value,))
    if kind == "passkey":
        if not value.isdigit() or int(value) > 999999:
            raise ValueError("Passkey must be 0–999999")
        return ("(u)", (int(value),))
    return None


class Agent:
    def __init__(self, bus):
        from gi.repository import GLib
        self.GLib = GLib
        self.bus = bus
        self.pending = {}   # id → (kind, invocation or None)
        self.paths = {}     # id → device path
        self.next_id = 1

    def device(self, path, prop):
        try:
            v = self.bus.call_sync("org.bluez", path, "org.freedesktop.DBus.Properties", "Get",
                                   self.GLib.Variant("(ss)", ("org.bluez.Device1", prop)),
                                   self.GLib.VariantType("(v)"), 0, 2000, None)
            return v.unpack()[0]
        except Exception:
            return None

    def request(self, kind, path, invocation, passkey=None, entered=None):
        rid = self.next_id
        self.next_id += 1
        self.pending[rid] = (kind, invocation)
        self.paths[rid] = path
        emit({"event": "request", "id": rid, "kind": kind, "device": path,
              "name": self.device(path, "Alias") or self.device(path, "Name") or path.rsplit("/", 1)[-1][4:].replace("_", ":"),
              "passkey": passkey, "entered": entered})
        return rid

    def answer(self, rid, accept, value):
        kind, invocation = self.pending.pop(rid, (None, None))
        if invocation is None:
            return
        if not accept:
            invocation.return_dbus_error(REJECTED, "Rejected by the user")
            return
        try:
            result = reply_value(kind, value)
        except ValueError as e:
            invocation.return_dbus_error(REJECTED, str(e))
            return
        invocation.return_value(self.GLib.Variant(*result) if result else None)

    def properties_changed(self, conn, sender, path, iface, signal, params):
        changed_iface, changed, _ = params.unpack()
        if changed_iface != "org.bluez.Device1" or changed.get("Paired") is not True:
            return
        for rid in [r for r, (k, inv) in self.pending.items() if k == "display" and self.paths.get(r) == path]:
            self.pending.pop(rid)
            emit({"event": "done", "id": rid})

    def cancel_all(self):
        for rid, (kind, invocation) in list(self.pending.items()):
            if invocation is not None:
                invocation.return_dbus_error(CANCELED, "Canceled")
            emit({"event": "cancel", "id": rid})
        self.pending.clear()

    def call(self, conn, sender, path, iface, method, params, invocation):
        args = params.unpack()
        if method in ("Release", "Cancel"):
            self.cancel_all()
            invocation.return_value(None)
        elif method == "RequestPinCode":
            self.request("pin", args[0], invocation)
        elif method == "RequestPasskey":
            self.request("passkey", args[0], invocation)
        elif method == "DisplayPinCode":
            self.request("display", args[0], None, passkey=args[1])
            invocation.return_value(None)
        elif method == "DisplayPasskey":
            # Called again for every digit typed on the device; one prompt.
            shown = [r for r, (k, _) in self.pending.items() if k == "display"]
            if shown:
                emit({"event": "update", "id": shown[0], "entered": args[2]})
            else:
                self.request("display", args[0], None, passkey="%06d" % args[1], entered=args[2])
            invocation.return_value(None)
        elif method == "RequestConfirmation":
            self.request("confirm", args[0], invocation, passkey="%06d" % args[1])
        elif method == "RequestAuthorization":
            self.request("authorize", args[0], invocation)
        elif method == "AuthorizeService":
            if self.device(args[0], "Paired") and self.device(args[0], "Trusted"):
                invocation.return_value(None)
            else:
                self.request("service", args[0], invocation)
        else:
            invocation.return_dbus_error(REJECTED, "Unknown method")


def main():
    try:
        import gi
        gi.require_version("Gio", "2.0")
        from gi.repository import Gio, GLib
    except (ImportError, ValueError):
        emit({"event": "error", "message": "python-gobject is not installed"})
        return 1
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        agent = Agent(bus)
        node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
        bus.register_object(AGENT_PATH, node.interfaces[0], agent.call, None, None)
        bus.signal_subscribe("org.bluez", "org.freedesktop.DBus.Properties", "PropertiesChanged", None,
                             "org.bluez.Device1", Gio.DBusSignalFlags.NONE, agent.properties_changed)
        manager = ("org.bluez", "/org/bluez", "org.bluez.AgentManager1")
        bus.call_sync(*manager, "RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY)), None, 0, 5000, None)
        bus.call_sync(*manager, "RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)), None, 0, 5000, None)
    except GLib.Error as e:
        emit({"event": "error", "message": e.message})
        return 1

    loop = GLib.MainLoop()

    def on_stdin(channel, condition):
        if condition & (GLib.IO_HUP | GLib.IO_ERR):
            loop.quit()
            return False
        line = channel.readline()
        if not line:
            loop.quit()
            return False
        reply = parse_reply(line)
        if reply:
            agent.answer(*reply)
        return True

    channel = GLib.IOChannel.unix_new(sys.stdin.fileno())
    GLib.io_add_watch(channel, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    emit({"event": "ready"})
    loop.run()
    try:
        bus.call_sync(*manager, "UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)), None, 0, 2000, None)
    except GLib.Error:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
