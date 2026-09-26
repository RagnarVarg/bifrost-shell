pragma Singleton

import QtQuick
import Quickshell
import qs.Core

// Current weather and a short forecast from Open-Meteo (api.open-meteo.com,
// no key; see docs/EXTERNAL-APIS.md) for the location ThemeMode uses: the
// one set in Appearance, else the time zone's. Coordinates are rounded to
// two decimals (about 1 km) before they leave the machine.
//
// Fetches only while retained (the clock menu is open), at most every
// `maxAgeMs`. `status`:
//   off         – turned off (clock.menu.weather)
//   nolocation  – no location known
//   loading     – first request under way
//   ok          – `current`/`daily` hold fresh data
//   offline     – no network (NetworkStatus, or the request never got an answer)
//   error       – the service answered with an error or unreadable data
// On offline/error the last data is kept and `stale` is set.
Singleton {
    id: root

    readonly property bool enabled: ((Config.values.clock || {}).menu || {}).weather !== false
    readonly property bool fahrenheit: ((Config.values.clock || {}).menu || {}).temperatureUnit === "fahrenheit"
    readonly property var savedLocation: Config.get("clock.weather.location")
    function validLocation(v) { return v && typeof v.lat === "number" && isFinite(v.lat) && Math.abs(v.lat) <= 90 && typeof v.lon === "number" && isFinite(v.lon) && Math.abs(v.lon) <= 180; }
    readonly property var location: validLocation(savedLocation) ? savedLocation : ThemeMode.location
    readonly property string place: location && location.name ? location.name : location && location.zone ? location.zone.split("/").pop().replace(/_/g, " ") : ""

    property string status: !enabled ? "off" : !location ? "nolocation" : "loading"
    property var current: null         // { temperature, feelsLike, code, isDay, wind, humidity }
    property var daily: []              // [{ date, max, min, code }]
    property var updatedAt: null
    readonly property bool hasData: current !== null
    readonly property bool stale: hasData && status !== "ok"

    readonly property int maxAgeMs: 15 * 60 * 1000
    readonly property int timeoutMs: 10000
    property int users: 0
    property string _key: ""            // request the data belongs to (place + unit)
    property var _xhr: null

    function retain() {
        users++;
        if (users === 1)
            refresh(false);
    }

    function release() {
        users = Math.max(0, users - 1);
    }

    function requestKey() {
        return location ? [location.lat.toFixed(2), location.lon.toFixed(2), fahrenheit ? "f" : "c"].join(",") : "";
    }

    function refresh(force: bool) {
        if (!enabled) {
            status = "off";
            return;
        }
        if (!location) {
            status = "nolocation";
            return;
        }
        const key = requestKey();
        if (key !== _key) {
            current = null;
            daily = [];
            updatedAt = null;
        }
        if (!force && key === _key && updatedAt && Date.now() - updatedAt.getTime() < maxAgeMs && status === "ok")
            return;
        if (!NetworkStatus.connected) {
            status = "offline";
            return;
        }
        if (_xhr)
            return;
        if (!hasData)
            status = "loading";
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + location.lat.toFixed(2) + "&longitude=" + location.lon.toFixed(2)
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m"
            + "&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=4&timezone=auto"
            + (fahrenheit ? "&temperature_unit=fahrenheit" : "");
        const xhr = new XMLHttpRequest();
        _xhr = xhr;
        timeout.restart();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || _xhr !== xhr)
                return;
            timeout.stop();
            _xhr = null;
            if (xhr.status === 0) {
                status = "offline";
                return;
            }
            const parsed = xhr.status === 200 ? parse(xhr.responseText) : null;
            if (!parsed) {
                status = "error";
                return;
            }
            current = parsed.current;
            daily = parsed.daily;
            updatedAt = new Date();
            _key = key;
            status = "ok";
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Open-Meteo's JSON → { current, daily }, or null if it is not usable.
    function parse(text: string): var {
        let d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return null;
        }
        const c = d && d.current;
        if (!c || typeof c.temperature_2m !== "number" || typeof c.weather_code !== "number")
            return null;
        const dd = d.daily || {};
        const days = (dd.time || []).map((t, i) => ({
                    date: new Date(t + "T12:00:00"),
                    max: (dd.temperature_2m_max || [])[i],
                    min: (dd.temperature_2m_min || [])[i],
                    code: (dd.weather_code || [])[i]
                })).filter(x => typeof x.max === "number" && typeof x.min === "number");
        return {
            current: {
                temperature: c.temperature_2m,
                feelsLike: typeof c.apparent_temperature === "number" ? c.apparent_temperature : c.temperature_2m,
                code: c.weather_code,
                isDay: c.is_day !== 0,
                wind: typeof c.wind_speed_10m === "number" ? c.wind_speed_10m : NaN,
                humidity: typeof c.relative_humidity_2m === "number" ? c.relative_humidity_2m : NaN
            },
            daily: days
        };
    }

    // WMO weather interpretation codes (as used by Open-Meteo).
    function kind(code: int): string {
        if (code <= 1)
            return "clear";
        if (code === 2)
            return "partly";
        if (code === 3)
            return "cloudy";
        if (code === 45 || code === 48)
            return "fog";
        if (code >= 51 && code <= 67 || code >= 80 && code <= 82)
            return "rain";
        if (code >= 71 && code <= 77 || code === 85 || code === 86)
            return "snow";
        if (code >= 95)
            return "storm";
        return "cloudy";
    }

    function icon(code: int, isDay: bool): string {
        return ({
                clear: isDay ? "sun" : "moon",
                partly: isDay ? "cloud-sun" : "cloud",
                cloudy: "cloud",
                fog: "cloud-fog",
                rain: "cloud-rain",
                snow: "cloud-snow",
                storm: "cloud-lightning"
            })[kind(code)];
    }

    function describe(code: int): string {
        if (code === 0)
            return I18n.tr("Clear");
        if (code === 1)
            return I18n.tr("Mainly clear");
        if (code === 2)
            return I18n.tr("Partly cloudy");
        if (code === 3)
            return I18n.tr("Overcast");
        if (code === 45 || code === 48)
            return I18n.tr("Fog");
        if (code >= 51 && code <= 57)
            return I18n.tr("Drizzle");
        if (code >= 61 && code <= 67 || code >= 80 && code <= 82)
            return I18n.tr("Rain");
        if (code >= 71 && code <= 77 || code === 85 || code === 86)
            return I18n.tr("Snow");
        if (code >= 95)
            return I18n.tr("Thunderstorm");
        return I18n.tr("Cloudy");
    }

    function degrees(v: real): string {
        return isNaN(v) ? "–" : Math.round(v) + "°";
    }

    onEnabledChanged: if (users > 0)
        refresh(true)
    onFahrenheitChanged: if (users > 0)
        refresh(true)
    onLocationChanged: {
        if (_xhr) { const old = _xhr; _xhr = null; old.abort(); timeout.stop(); }
        current = null; daily = []; updatedAt = null; _key = "";
        if (users > 0) refresh(true);
    }

    Connections {
        target: NetworkStatus

        function onConnectedChanged() {
            if (NetworkStatus.connected && root.users > 0)
                root.refresh(root.status !== "ok");
            else if (!NetworkStatus.connected && root.status === "ok")
                root.status = "offline";
        }
    }

    // Refresh while retained.
    Timer {
        running: root.users > 0 && root.enabled
        interval: root.maxAgeMs
        repeat: true
        onTriggered: root.refresh(true)
    }

    // A request that never answers counts as offline.
    Timer {
        id: timeout

        interval: root.timeoutMs
        onTriggered: if (root._xhr) {
            const x = root._xhr;
            root._xhr = null;
            x.abort();
            root.status = "offline";
        }
    }
}
