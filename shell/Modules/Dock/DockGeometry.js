.pragma library

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
function rect(edge, width, height, length, thickness, insets, margin, fx, fy) {
    const vertical = edge === "left" || edge === "right";
    const w = Math.min(vertical ? thickness : length, width - insets.left - insets.right);
    const h = Math.min(vertical ? length : thickness, height - insets.top - insets.bottom);
    const x0 = insets.left, y0 = insets.top;
    const x1 = Math.max(x0, width - insets.right - w), y1 = Math.max(y0, height - insets.bottom - h);
    let x = (x0 + x1) / 2, y = (y0 + y1) / 2;
    if (edge === "left") x = x0 + margin;
    else if (edge === "right") x = x1 - margin;
    else if (edge === "top") y = y0 + margin;
    else if (edge === "bottom") y = y1 - margin;
    else { x = x0 + (x1 - x0) * clamp(fx, 0, 1); y = y0 + (y1 - y0) * clamp(fy, 0, 1); }
    return { x: clamp(x, x0, x1), y: clamp(y, y0, y1), width: w, height: h };
}
function panel(edge, dock, sw, sh, pw, ph, gap) {
    let x = dock.x + (dock.width - pw) / 2, y = dock.y - ph;
    if (edge === "top") y = dock.y + dock.height;
    if (edge === "left") { x = dock.x + dock.width; y = dock.y + (dock.height - ph) / 2; }
    if (edge === "right") { x = dock.x - pw; y = dock.y + (dock.height - ph) / 2; }
    return { x: clamp(x, gap, Math.max(gap, sw - pw - gap)), y: clamp(y, gap, Math.max(gap, sh - ph - gap)), width: pw, height: ph };
}

// Only the part protruding into the desktop joins the frame. As autohide
// translates the dock outward, this shrinks continuously to the frame edge.
function frameExtension(edge, rect, width, height, border) {
    const out={x:rect.x,y:rect.y,width:rect.width,height:rect.height};
    if(edge==="bottom") out.height=clamp(height-border-rect.y,0,rect.height);
    else if(edge==="top") {out.y=border;out.height=clamp(rect.y+rect.height-border,0,rect.height);}
    else if(edge==="right") out.width=clamp(width-border-rect.x,0,rect.width);
    else if(edge==="left") {out.x=border;out.width=clamp(rect.x+rect.width-border,0,rect.width);}
    return out.width>0 && out.height>0 ? out : null;
}
