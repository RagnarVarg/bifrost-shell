#!/usr/bin/env python3
"""NetworkStatus adapter: create and activate a hidden Wi-Fi profile through NM.
Receives one JSON line over stdin. Secrets never enter argv or Bifrost config.
"""
import json
import re
import sys
import uuid


def validate(data):
    if not isinstance(data, dict):
        raise ValueError('Expected network object')
    ssid = data.get('ssid', '')
    password = data.get('password', '')
    interface = data.get('interface', '')
    if not isinstance(ssid, str) or not 1 <= len(ssid.encode()) <= 32:
        raise ValueError('SSID must contain 1–32 bytes')
    if not isinstance(interface, str) or not re.fullmatch(r'[a-zA-Z0-9_.-]{1,64}', interface):
        raise ValueError('Invalid Wi-Fi interface')
    if not isinstance(password, str):
        raise ValueError('Invalid passphrase type')
    if password and not (8 <= len(password) <= 63 or re.fullmatch(r'[0-9a-fA-F]{64}', password)):
        raise ValueError('Invalid WPA personal passphrase')
    return ssid, password, interface


def connect(data):
    ssid, password, interface = validate(data)
    from gi.repository import Gio, GLib
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    path = '/org/freedesktop/NetworkManager'
    service = 'org.freedesktop.NetworkManager'
    device = bus.call_sync(service, path, service, 'GetDeviceByIpIface', GLib.Variant('(s)', (interface,)),
                           GLib.VariantType('(o)'), Gio.DBusCallFlags.NONE, 10000, None).unpack()[0]
    props = {
        'connection': {'id': GLib.Variant('s', ssid), 'uuid': GLib.Variant('s', str(uuid.uuid4())),
                       'type': GLib.Variant('s', '802-11-wireless'), 'autoconnect': GLib.Variant('b', True)},
        '802-11-wireless': {'ssid': GLib.Variant('ay', list(ssid.encode())), 'hidden': GLib.Variant('b', True),
                           'mode': GLib.Variant('s', 'infrastructure')},
        'ipv4': {'method': GLib.Variant('s', 'auto')}, 'ipv6': {'method': GLib.Variant('s', 'auto')}
    }
    if password:
        props['802-11-wireless-security'] = {'key-mgmt': GLib.Variant('s', 'wpa-psk'), 'psk': GLib.Variant('s', password)}
    bus.call_sync(service, path, service, 'AddAndActivateConnection', GLib.Variant('(a{sa{sv}}oo)', (props, device, '/')),
                  GLib.VariantType('(oo)'), Gio.DBusCallFlags.NONE, 15000, None)


if __name__ == '__main__':
    try:
        data = json.loads(sys.stdin.readline(4097))
        connect(data)
        print(json.dumps({'requested': True}))
    except Exception:
        # Never echo input or secret-bearing D-Bus values in diagnostics.
        print(json.dumps({'error': 'Could not activate hidden network'}))
        sys.exit(1)
