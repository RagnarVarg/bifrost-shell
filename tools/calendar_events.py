#!/usr/bin/env python3
"""Today's calendar events from Evolution Data Server (the calendars GNOME
Calendar, Evolution and GNOME Online Accounts use), as JSON for the clock
menu (Services/Calendar.qml):

  {"status": "ok", "calendars": ["Personal", …], "events": [
     {"title", "start", "end" (epoch ms), "allDay", "calendar", "location"}]}
  {"status": "unavailable", "reason": "…"}   no EDS or no enabled calendar

Recurring events are expanded. Read only; never writes to a calendar.
"""
import json
import os
import sys
from datetime import datetime, timedelta


def unavailable(reason):
    print(json.dumps({"status": "unavailable", "reason": reason}))
    return 0


def day_bounds(day=None):
    start = datetime.combine(day or datetime.now().date(), datetime.min.time())
    return int(start.timestamp()), int((start + timedelta(days=1)).timestamp())


def local_zone_name():
    """The system time zone (e.g. Europe/Stockholm), or "" if unknown."""
    tz = os.environ.get("TZ", "").lstrip(":")
    if tz and "/" in tz:
        return tz
    try:
        return os.path.realpath("/etc/localtime").split("/zoneinfo/", 1)[1]
    except (OSError, IndexError):
        return ""


def to_epoch(t):
    """ICalGLib.Time → (epoch seconds, all day). Dates and floating times
    (no time zone) are local time."""
    from gi.repository import ICalGLib
    if t is None or t.is_null_time():
        return None, False
    if t.is_date():
        return int(datetime(t.get_year(), t.get_month(), t.get_day()).timestamp()), True
    if t.is_utc():
        return t.as_timet_with_zone(ICalGLib.Timezone.get_utc_timezone()), False
    if t.get_timezone() is not None:
        return t.as_timet_with_zone(t.get_timezone()), False
    return int(datetime(t.get_year(), t.get_month(), t.get_day(), t.get_hour(), t.get_minute(), t.get_second()).timestamp()), False


def events(day=None):
    try:
        import gi
        gi.require_version("EDataServer", "1.2")
        gi.require_version("ECal", "2.0")
        gi.require_version("ICalGLib", "3.0")
        from gi.repository import ECal, EDataServer, ICalGLib
    except (ImportError, ValueError):
        return None, "Evolution Data Server is not installed"
    try:
        registry = EDataServer.SourceRegistry.new_sync(None)
    except Exception as e:  # noqa: BLE001 – D-Bus errors come as GLib.Error
        return None, f"Evolution Data Server did not answer ({e})"
    sources = [s for s in registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR) if s.get_enabled()]
    if not sources:
        return None, "No calendar is set up"
    start, end = day_bounds(day)
    # Floating times (no time zone) are the system's local time.
    local = ICalGLib.Timezone.get_builtin_timezone(local_zone_name()) if local_zone_name() else None
    out, names = [], []
    for source in sources:
        try:
            # Wait at most a second for an online calendar to reconnect (EDS
            # answers from its cache after that). The local calendar never
            # reports "connected", so a longer wait only delays it; 0 = forever.
            client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 1, None)
        except Exception:  # noqa: BLE001 – one broken calendar must not hide the rest
            continue
        names.append(source.get_display_name())
        if local:
            client.set_default_timezone(local)

        def add(comp, istart, iend, *_):
            s, all_day = to_epoch(istart)
            e, _ = to_epoch(iend)
            if s is None:
                return True
            if e is None or e <= s:
                e = s + (86400 if all_day else 0)
            if e <= start or s >= end:
                return True
            out.append({"title": comp.get_summary() or "", "start": s * 1000, "end": e * 1000, "allDay": all_day,
                        "calendar": source.get_display_name(), "location": comp.get_location() or ""})
            return True

        # EDS picks the instances with floating times read as UTC: ask for a
        # day more on each side and keep what overlaps the local day (add).
        client.generate_instances_sync(start - 86400, end + 86400, None, add)
    if not names:
        return None, "The calendars could not be opened"
    out.sort(key=lambda x: (not x["allDay"], x["start"], x["title"].lower()))
    return {"calendars": names, "events": out}, ""


def main(argv):
    day = datetime.strptime(argv[1], "%Y-%m-%d").date() if len(argv) > 1 else None
    data, reason = events(day)
    if data is None:
        return unavailable(reason)
    print(json.dumps(dict(status="ok", **data), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
