pragma Singleton

import QtQuick
import Quickshell
import qs.Compat
import qs.Core

// Wall clock. Ticks per second only when a consumer shows seconds.
Singleton {
    readonly property date now: clock.date
    // clock.locale, else the system's; BIFROST_LANG (tests, like I18n) stands
    // in for the system language.
    readonly property string localeName: Config.values.clock && Config.values.clock.locale !== "system" ? Config.values.clock.locale : Platform.env("BIFROST_LANG")
    readonly property var locale: Qt.locale(localeName)

    function format(d: date, fmt: string): string {
        return locale.toString(d, fmt);
    }

    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    SystemClock {
        id: clock

        precision: Config.values.clock && Config.values.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
