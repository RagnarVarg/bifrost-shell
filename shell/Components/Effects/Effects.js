.pragma library

// Helpers shared by the Bifrost Effects components.

// `c` with its HSL saturation scaled by `amount` (0 = grey, 1 = unchanged)
// and alpha `a`.
function tone(c, amount, a) {
    const s = Math.max(0, c.hslSaturation) * Math.max(0, Math.min(1, amount));
    return Qt.hsla(Math.max(0, c.hslHue), s, c.hslLightness, a);
}

// Segments [start, end] of a line of `length` with the span
// [gapStart, gapStart + gapWidth] cut out (a menu joined to the glass there).
function segments(length, gapStart, gapWidth) {
    if (!(gapWidth > 0) || gapStart >= length || gapStart + gapWidth <= 0)
        return [[0, length]];
    const out = [];
    if (gapStart > 0)
        out.push([0, gapStart]);
    if (gapStart + gapWidth < length)
        out.push([gapStart + gapWidth, length]);
    return out;
}
