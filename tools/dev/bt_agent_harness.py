#!/usr/bin/env python3
"""End-to-end check of tools/bt_agent.py against a fake BlueZ on a private bus.

Run inside `dbus-run-session -- python3 tools/dev/bt_agent_harness.py`: the
agent's "system bus" is pointed at that session bus, so the real BlueZ is
never touched. Prints one JSON object with every observed result.
"""
import json
import os
import subprocess
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore", category=DeprecationWarning)

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

AGENT = str(Path(__file__).resolve().parent.parent / "bt_agent.py")
DEV = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
BLUEZ_XML = """
<node>
  <interface name="org.bluez.AgentManager1">
    <method name="RegisterAgent"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
    <method name="RequestDefaultAgent"><arg type="o" direction="in"/></method>
    <method name="UnregisterAgent"><arg type="o" direction="in"/></method>
  </interface>
  <interface name="org.freedesktop.DBus.Properties">
    <method name="Get"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
state = {"registered": None, "default": None, "paired": False, "trusted": False}


def bluez_call(conn, sender, path, iface, method, params, inv):
    args = params.unpack()
    if method == "RegisterAgent":
        state["registered"] = [sender, args[0], args[1]]
        inv.return_value(None)
    elif method == "RequestDefaultAgent":
        state["default"] = args[0]
        inv.return_value(None)
    elif method == "UnregisterAgent":
        inv.return_value(None)
    elif method == "Get":
        values = {"Alias": GLib.Variant("s", "Test Keyboard"), "Name": GLib.Variant("s", "Test Keyboard"),
                  "Paired": GLib.Variant("b", state["paired"]), "Trusted": GLib.Variant("b", state["trusted"])}
        inv.return_value(GLib.Variant("(v)", (values[args[1]],)))


node = Gio.DBusNodeInfo.new_for_xml(BLUEZ_XML)
bus.register_object("/org/bluez", node.interfaces[0], bluez_call, None, None)
bus.register_object(DEV, node.interfaces[1], bluez_call, None, None)
Gio.bus_own_name_on_connection(bus, "org.bluez", Gio.BusNameOwnerFlags.NONE, None, None)

env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=os.environ["DBUS_SESSION_BUS_ADDRESS"])
proc = subprocess.Popen([sys.executable, AGENT], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
loop = GLib.MainLoop()
events = []
results = {}


def pump_until(pred, timeout=5000):
    """Run the main loop until pred() holds (agent output is read by a watch)."""
    deadline = GLib.get_monotonic_time() + timeout * 1000
    ctx = loop.get_context()
    while not pred() and GLib.get_monotonic_time() < deadline:
        ctx.iteration(True)
    return pred()


def on_out(channel, cond):
    line = proc.stdout.readline()
    if not line:
        return False
    events.append(json.loads(line))
    return True


GLib.io_add_watch(GLib.IOChannel.unix_new(proc.stdout.fileno()), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_out)


def reply(obj):
    proc.stdin.write(json.dumps(obj) + "\n")
    proc.stdin.flush()


def call(name, method, sig, args, answer=None, wait=True):
    """Calls an agent method; answers its request (if any) and records the outcome."""
    sender = state["registered"][0]
    box = {}

    def done(src, res):
        try:
            box["value"] = src.call_finish(res).unpack()
        except GLib.Error as e:
            box["error"] = Gio.DBusError.get_remote_error(e)

    bus.call(sender, state["registered"][1], "org.bluez.Agent1", method, GLib.Variant(sig, args) if sig else None,
             None, Gio.DBusCallFlags.NONE, 5000, None, done)
    if answer is not None:
        n = len([e for e in events if e.get("event") == "request"])
        pump_until(lambda: len([e for e in events if e.get("event") == "request"]) > n)
        req = [e for e in events if e.get("event") == "request"][-1]
        results[name + ":request"] = {k: req[k] for k in ("kind", "name", "passkey")}
        reply({"id": req["id"], **answer})
    results[name] = box
    if wait:
        pump_until(lambda: box)


pump_until(lambda: any(e.get("event") in ("ready", "error") for e in events))
results["ready"] = events[-1]
results["registered"] = state["registered"][1:] if state["registered"] else None
results["default"] = state["default"]

call("confirm", "RequestConfirmation", "(ou)", (DEV, 42), {"accept": True})
call("confirm-reject", "RequestConfirmation", "(ou)", (DEV, 7), {"accept": False})
call("passkey", "RequestPasskey", "(o)", (DEV,), {"accept": True, "value": "123456"})
call("passkey-bad", "RequestPasskey", "(o)", (DEV,), {"accept": True, "value": "12x"})
call("pin", "RequestPinCode", "(o)", (DEV,), {"accept": True, "value": "0000"})
call("service-unknown", "AuthorizeService", "(os)", (DEV, "0000110b-0000-1000-8000-00805f9b34fb"), {"accept": True})
state["paired"] = state["trusted"] = True
call("service-trusted", "AuthorizeService", "(os)", (DEV, "0000110b-0000-1000-8000-00805f9b34fb"))
state["paired"] = False
call("display", "DisplayPasskey", "(ouq)", (DEV, 1234, 0))
call("display-typed", "DisplayPasskey", "(ouq)", (DEV, 1234, 3))
bus.emit_signal(None, DEV, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                GLib.Variant("(sa{sv}as)", ("org.bluez.Device1", {"Paired": GLib.Variant("b", True)}, [])))
pump_until(lambda: any(e.get("event") == "done" for e in events))
call("authorize", "RequestAuthorization", "(o)", (DEV,), wait=False)  # left open, then BlueZ cancels
pump_until(lambda: len([e for e in events if e.get("event") == "request"]) >= 8)
call("cancel", "Cancel", None, None)
pump_until(lambda: results["authorize"] and any(e.get("event") == "cancel" for e in events))
results["events"] = [e["event"] for e in events]
results["display"] = [e for e in events if e.get("kind") == "display" or e.get("event") in ("update", "done")]
proc.stdin.close()
results["exit"] = proc.wait(5)
print(json.dumps(results))
