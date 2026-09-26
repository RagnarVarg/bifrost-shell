#!/usr/bin/env python3
"""Dev aid: a minimal MPRIS player on the session bus, for testing Bifrost's
media UI (clock menu, control center) where no real player is available.
It plays nothing: it reports a track with length/position that advance while
"playing" and obeys PlayPause/Next/Previous. Run it on a nested instance's bus:
    DBUS_SESSION_BUS_ADDRESS=<nested> tools/dev/mpris-fixture.py [--art FILE]
Stop with Ctrl+C / kill.
"""
import argparse
import time

from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/><method name="Quit"/>
    <property name="Identity" type="s" access="read"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/><method name="Previous"/><method name="Pause"/>
    <method name="PlayPause"/><method name="Stop"/><method name="Play"/>
    <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
    <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
    <signal name="Seeked"><arg name="Position" type="x"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""

TRACKS = [("Aurora över fjället", "Bifrost Test Ensemble", 214), ("Nordlys", "Testspelaren", 187)]


class Player:
    def __init__(self, art):
        self.art = art
        self.index = 0
        self.playing = True
        self.base = 42.0            # seconds at `since`
        self.since = time.monotonic()
        self.conn = None

    def position(self):
        return self.base + (time.monotonic() - self.since if self.playing else 0)

    def metadata(self):
        title, artist, length = TRACKS[self.index]
        md = {
            "mpris:trackid": GLib.Variant("o", f"/org/bifrost/track/{self.index}"),
            "mpris:length": GLib.Variant("x", length * 1_000_000),
            "xesam:title": GLib.Variant("s", title),
            "xesam:artist": GLib.Variant("as", [artist]),
            "xesam:album": GLib.Variant("s", "Fixture"),
        }
        if self.art:
            md["mpris:artUrl"] = GLib.Variant("s", "file://" + self.art)
        return md

    def props(self):
        return {
            "PlaybackStatus": GLib.Variant("s", "Playing" if self.playing else "Paused"),
            "Metadata": GLib.Variant("a{sv}", self.metadata()),
            "Position": GLib.Variant("x", int(self.position() * 1_000_000)),
            "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True),
            "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
            "CanSeek": GLib.Variant("b", True), "CanControl": GLib.Variant("b", True),
            "Rate": GLib.Variant("d", 1.0), "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0),
            "Volume": GLib.Variant("d", 1.0),
            "Identity": GLib.Variant("s", "Bifrost MPRIS fixture"), "CanQuit": GLib.Variant("b", False),
            "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", False),
            "DesktopEntry": GLib.Variant("s", ""), "SupportedUriSchemes": GLib.Variant("as", []),
            "SupportedMimeTypes": GLib.Variant("as", []),
        }

    def changed(self, names):
        p = self.props()
        self.conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                              GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", {n: p[n] for n in names}, [])))

    def call(self, conn, sender, path, iface, method, params, inv):
        if method in ("PlayPause", "Play", "Pause", "Stop"):
            self.base = self.position()
            self.since = time.monotonic()
            self.playing = {"PlayPause": not self.playing, "Play": True}.get(method, False)
            self.changed(["PlaybackStatus"])
        elif method in ("Next", "Previous"):
            self.index = (self.index + (1 if method == "Next" else -1)) % len(TRACKS)
            self.base, self.since = 0.0, time.monotonic()
            self.changed(["Metadata", "PlaybackStatus"])
        print("call", method, flush=True)
        inv.return_value(None)

    def get(self, conn, sender, path, iface, name):
        return self.props().get(name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--art")
    a = ap.parse_args()
    player = Player(a.art)
    node = Gio.DBusNodeInfo.new_for_xml(XML)

    def on_bus(conn, name):
        player.conn = conn
        for iface in node.interfaces:
            conn.register_object("/org/mpris/MediaPlayer2", iface, player.call, player.get, None)

    Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.bifrostfixture", Gio.BusNameOwnerFlags.NONE, on_bus, None, None)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
