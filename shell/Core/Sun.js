.pragma library

// Sunrise and sunset for a date and place (NOAA solar position algorithm,
// accurate to about a minute). Pure functions, no network.
//
//   times(date, lat, lon) -> { sunrise: Date|null, sunset: Date|null, polar: "day"|"night"|"" }
//   isDaylight(now, lat, lon) -> bool
//   nextChange(now, lat, lon) -> Date|null     the next sunrise or sunset after `now`

const RAD = Math.PI / 180;

function julianDay(date) {
    return date.getTime() / 86400000 + 2440587.5;
}

function fromJulian(jd) {
    return new Date((jd - 2440587.5) * 86400000);
}

// Solar declination and equation of time for Julian day jd.
function solar(jd) {
    const t = (jd - 2451545.0) / 36525;
    const l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    const m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
    const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    const c = Math.sin(m * RAD) * (1.914602 - t * (0.004817 + 0.000014 * t)) + Math.sin(2 * m * RAD) * (0.019993 - 0.000101 * t) + Math.sin(3 * m * RAD) * 0.000289;
    const trueLong = l0 + c;
    const omega = 125.04 - 1934.136 * t;
    const lambda = trueLong - 0.00569 - 0.00478 * Math.sin(omega * RAD);
    const eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    const eps = eps0 + 0.00256 * Math.cos(omega * RAD);
    const decl = Math.asin(Math.sin(eps * RAD) * Math.sin(lambda * RAD)) / RAD;
    const y = Math.pow(Math.tan(eps * RAD / 2), 2);
    const eqTime = 4 / RAD * (y * Math.sin(2 * l0 * RAD) - 2 * e * Math.sin(m * RAD) + 4 * e * y * Math.sin(m * RAD) * Math.cos(2 * l0 * RAD) - 0.5 * y * y * Math.sin(4 * l0 * RAD) - 1.25 * e * e * Math.sin(2 * m * RAD));
    return { decl: decl, eqTime: eqTime };
}

// Minutes after UTC midnight of the event; rising = true for sunrise.
function eventUtcMinutes(jdNoon, lat, lon, rising) {
    let minutes = 720 - 4 * lon;
    // Two iterations converge well enough.
    for (let i = 0; i < 2; i++) {
        const s = solar(jdNoon - 0.5 + minutes / 1440);
        const cosH = (Math.cos(90.833 * RAD) - Math.sin(lat * RAD) * Math.sin(s.decl * RAD)) / (Math.cos(lat * RAD) * Math.cos(s.decl * RAD));
        if (cosH > 1)
            return { polar: "night" };
        if (cosH < -1)
            return { polar: "day" };
        const h = Math.acos(cosH) / RAD;
        minutes = 720 - 4 * (lon + (rising ? h : -h)) - s.eqTime;
    }
    return { minutes: minutes };
}

function times(date, lat, lon) {
    const utcMidnight = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
    const jdNoon = julianDay(new Date(utcMidnight)) + 0.5;
    const r = eventUtcMinutes(jdNoon, lat, lon, true);
    const s = eventUtcMinutes(jdNoon, lat, lon, false);
    if (r.polar || s.polar)
        return { sunrise: null, sunset: null, polar: r.polar || s.polar };
    return {
        sunrise: new Date(utcMidnight + r.minutes * 60000),
        sunset: new Date(utcMidnight + s.minutes * 60000),
        polar: ""
    };
}

function isDaylight(now, lat, lon) {
    const t = times(now, lat, lon);
    if (t.polar)
        return t.polar === "day";
    return now >= t.sunrise && now < t.sunset;
}

function nextChange(now, lat, lon) {
    for (let d = 0; d < 370; d++) {
        const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + d);
        const t = times(day, lat, lon);
        if (t.polar)
            continue;
        for (const ev of [t.sunrise, t.sunset])
            if (ev > now)
                return ev;
    }
    return null;
}

// "+5920+01803" (ISO 6709, zone1970.tab) -> { lat, lon }
function parseIso6709(s) {
    const m = /^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/.exec(s);
    if (!m)
        return null;
    const lat = (Number(m[2]) + Number(m[3]) / 60 + Number(m[4] || 0) / 3600) * (m[1] === "-" ? -1 : 1);
    const lon = (Number(m[6]) + Number(m[7]) / 60 + Number(m[8] || 0) / 3600) * (m[5] === "-" ? -1 : 1);
    return { lat: lat, lon: lon };
}
