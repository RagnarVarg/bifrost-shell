.pragma library

// "0.56.2", "v0.56.2-dirty", "3.14" -> [0, 56, 2]
function parse(v) {
    const m = String(v || "").match(/(\d+)(?:\.(\d+))?(?:\.(\d+))?/);
    return m ? [Number(m[1]), Number(m[2] || 0), Number(m[3] || 0)] : null;
}

function compare(a, b) {
    const pa = parse(a), pb = parse(b);
    if (!pa || !pb)
        return NaN;
    for (let i = 0; i < 3; i++)
        if (pa[i] !== pb[i])
            return pa[i] < pb[i] ? -1 : 1;
    return 0;
}

function atLeast(version, min) {
    if (!min)
        return true;
    return compare(version, min) >= 0;
}
