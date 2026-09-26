.pragma library

// One glass surface out of two: a panel (a bar menu, the control center on
// the dock, …) grown out of the glass it belongs to, as the
// GlassSurface.attachment for that glass. Worked out as if the panel hangs
// below the glass, then mirrored when it grows upward (`down` false).
//   glass: { width, radius, stripY, stripHeight, framed }
//     stripY/stripHeight – the part the panel grows from (all of a plain
//     glass; the bar side of a frame). framed: outer corners stay square.
//   x, width, height – the panel, x in the glass's own coordinates
//   fillet – concave corner radius where they meet; radius – the panel's
// Returns { ext, bridge, radii, extRadii, fillets } (see GlassSurface).
function attach(glass, x, width, height, down, fillet, radius) {
    const gw = glass.width, gh = glass.stripHeight, h = height;
    const mx = x, W = width;
    const r = Math.min(glass.radius, gh / 2);
    const R = radius;
    const out = { radii: [r, r, r, r], extRadii: [R, 0, R, 0], fillets: [] };

    // side: gap between glass edge and panel edge (> 0: the glass reaches
    // past the panel; < 0: the panel overhangs the glass).
    const side = (gap, left) => {
        const cornerIdx = left ? 2 : 0;         // bottom-left / bottom-right
        const extTopIdx = left ? 3 : 1;         // top-left / top-right
        const sx = left ? -1 : 1;
        if (Math.abs(gap) < 0.5) {
            out.radii[cornerIdx] = 0;
            return;
        }
        if (gap > 0) {
            const f = Math.min(gap > r ? Math.min(fillet, gap - r) : gap, h);
            if (gap <= r)
                out.radii[cornerIdx] = 0;
            const cx = left ? mx : mx + W;
            out.fillets.push([cx, gh, sx * f, f]);
        } else {
            const o = -gap;
            out.radii[cornerIdx] = 0;
            if (o > R)
                out.extRadii[extTopIdx] = R;
            const f = Math.min(o > R ? Math.min(fillet, o - R) : o, gh);
            const cx = left ? 0 : gw;
            out.fillets.push([cx, gh, sx * f, -f]);
        }
    };
    side(mx, true);
    side(gw - (mx + W), false);

    // The bridge spans the seam from the glass's middle into the panel.
    const bx = Math.max(mx, 0), bw = Math.min(mx + W, gw) - bx;
    let ext = { x: mx, y: gh, width: W, height: h };
    let bridge = { x: bx, y: gh / 2, width: Math.max(bw, 0), height: gh / 2 + Math.min(h, gh / 2) };
    if (!down) {
        ext = { x: mx, y: gh - ext.y - ext.height, width: W, height: ext.height };
        bridge = { x: bridge.x, y: gh - bridge.y - bridge.height, width: bridge.width, height: bridge.height };
        out.radii = [out.radii[1], out.radii[0], out.radii[3], out.radii[2]];
        out.extRadii = [out.extRadii[1], out.extRadii[0], out.extRadii[3], out.extRadii[2]];
        out.fillets = out.fillets.map(f => [f[0], gh - f[1], f[2], -f[3]]);
    }
    const sy = glass.stripY;
    out.ext = Qt.rect(ext.x, ext.y + sy, ext.width, ext.height);
    out.bridge = Qt.rect(bridge.x, bridge.y + sy, bridge.width, bridge.height);
    out.fillets = out.fillets.map(f => [f[0], f[1] + sy, f[2], f[3]]);
    if (glass.framed)
        out.radii = [0, 0, 0, 0];
    return out;
}

// Move/rotate an attachment, including its corner radii and concave joins.
function transform(a, point) {
    if (!a) return null;
    function rect(r) {
        const p = point(r.x, r.y), q = point(r.x + r.width, r.y + r.height);
        return Qt.rect(Math.min(p.x, q.x), Math.min(p.y, q.y), Math.abs(q.x-p.x), Math.abs(q.y-p.y));
    }
    function corners(values) {
        const out = [0, 0, 0, 0];
        const origin = point(0, 0);
        [[1,1],[1,-1],[-1,1],[-1,-1]].forEach((c,i) => {
            const p = point(c[0],c[1]);
            out[(p.x >= origin.x ? 0 : 2) + (p.y >= origin.y ? 0 : 1)] = values[i];
        });
        return out;
    }
    return { ext: rect(a.ext), bridge: rect(a.bridge), radii: corners(a.radii), extRadii: corners(a.extRadii), fillets: a.fillets.map(f => {
        const p = point(f[0],f[1]), q = point(f[0]+f[2],f[1]+f[3]);
        return [p.x,p.y,q.x-p.x,q.y-p.y];
    }) };
}

// Join screen-coordinate rectangles at any of the four edges.
function between(base, extension, edge, fillet, radius, framed) {
    const side = edge === "left" || edge === "right";
    const a = attach({width: side ? base.height : base.width, radius: radius,
        stripY: 0, stripHeight: side ? base.width : base.height, framed: framed},
        side ? extension.y-base.y : extension.x-base.x,
        side ? extension.height : extension.width, side ? extension.width : extension.height,
        edge === "top" || edge === "left", fillet, radius);
    return transform(a, (x,y) => side ? Qt.point(base.x+y,base.y+x) : Qt.point(base.x+x,base.y+y));
}
