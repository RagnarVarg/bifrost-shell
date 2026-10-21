"""Bifrost's own icon theme: folders, places, devices and common file types
drawn as SVG in the shell's palette. Standard library only.

Two drawings per icon:
  small (16 and 24 px, fixed size) – "Sten": flat and matte in two tones,
      edges on whole pixels, symbols cut into the front in a darker tone;
  large (32 px and up, scalable)   – "Norrsken": the front carries the
      palette's aurora under a light veil, a thin bright rim on top.
Everything else (app icons above all) comes from the inherited theme.

bifrostctl (`icons generate`) decides when to draw, where (the two theme
slots) and with which palette; this module only draws.
"""

from __future__ import annotations

import os
from pathlib import Path

# Raised whenever the drawings change, so every installed copy is redrawn.
VERSION = 1

SMALL_SIZES = (16, 24)


# ── colours ───────────────────────────────────────────────────────────────
def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, t):
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(_rgb(a), _rgb(b)))


def colours(dark, light, accent=None):
    """The icon colours from the palette of both modes ({slot: "#rrggbb"}).
    Icons don't change with light/dark: every tone sits between the two
    modes' accents, so it reads on light and on dark backgrounds alike.
    `accent` = {mode: colour} overrides the palettes' accents."""
    accent = accent or {}
    acc = {m: accent.get(m) or p.get("accent", "#8FA8C8") for m, p in (("dark", dark), ("light", light))}
    front = mix(acc["dark"], acc["light"], 0.4)
    au = [mix(a, b, 0.4) for a, b in zip(dark.get("aurora") or [acc["dark"]] * 3, light.get("aurora") or [acc["light"]] * 3)]
    status = {k: mix(dark.get(k, "#888888"), light.get(k, "#888888"), 0.5) for k in ("success", "warning", "danger")}
    return {
        "front": front,
        "back": mix(front, "#000000", 0.28),
        "deep": mix(front, "#000000", 0.45),
        "paper": "#fbfbfc",
        "page": mix(light.get("surfaceHover", "#dde2e9"), dark.get("surfaceRaised", "#1e2126"), 0.15),
        "line": mix(light.get("silver", "#5e6773"), "#ffffff", 0.55),
        "ink": mix(front, "#000000", 0.2),
        "glass": mix(light.get("surfaceRaised", "#fafbfc"), front, 0.12),
        "aurora0": au[0], "aurora1": au[1], "aurora2": au[2],
        **status,
    }


# Which colour pair a file type is tinted with: (small strip, large band).
TYPE_TINT = {"pdf": "danger", "spreadsheet": "success", "presentation": "warning"}


# ── symbols (on a 12 × 12 box; stroke, round caps) ──────────────────────────
GLYPHS = {
    "home": "M2 6.5 6 3l4 3.5M3.5 5.5V10h5V5.5",
    "desktop": "M1.5 2.5h9v6h-9zM4.5 10.5h3M6 8.5v2",
    "documents": "M3 1.5h4.5L9.5 3.5v7H3zM4.75 5.5h3M4.75 7.5h3",
    "download": "M6 1.5v6.5M3.25 5.5 6 8.25 8.75 5.5M2 10.5h8",
    "music": "M4.5 9.5V2.5l5-1v6.5M4.5 9.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0zM9.5 8a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z",
    "pictures": "M1.5 9.5 4.5 5l2.25 3L8 6.5l2.5 3zM8.5 3.25a.75.75 0 1 1 0 .01",
    "videos": "M3.5 2.5v7l6-3.5z",
    "templates": "M2 2h8v8H2zM2 5h8M5 5v5",
    "publicshare": "M3 6a1.25 1.25 0 1 1 0 .01M9 3a1.25 1.25 0 1 1 0 .01M9 9a1.25 1.25 0 1 1 0 .01M4.2 5.4 7.8 3.6M4.2 6.6 7.8 8.4",
    "projects": "M4 3 1.5 6 4 9M8 3l2.5 3L8 9M6.75 2.5 5.25 9.5",
    "fjord": "M2 7.5 4 5.5l2 2 2-2 2 2",
    "code": "M4 3 1.5 6 4 9M8 3l2.5 3L8 9",
    "image": "M1.5 9.5 4.5 5l2.25 3L8 6.5l2.5 3zM8.5 3.25a.75.75 0 1 1 0 .01",
    "audio": "M4.5 9.5V2.5l5-1v6.5M4.5 9.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0zM9.5 8a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0z",
    "video": "M1.5 2.5h9v7h-9zM5 4.5v3l2.5-1.5z",
    "archive": "M5 1.5h1M6 3h1M5 4.5h1M6 6h1M4.5 7.5h3v3h-3z",
    "pdf": "M3.5 1.5h5v9L6 8.5l-2.5 2z",
    "spreadsheet": "M1.5 2.5h9v7h-9zM1.5 5h9M1.5 7.5h9M5 2.5v7",
    "presentation": "M1.5 2h9v6h-9zM6 8v2.5M4 10.5h4M3.5 6.5v-1.5M6 6.5V4M8.5 6.5V3",
    "text": "M2 3h8M2 6h8M2 9h5",
}


def glyph(name, x, y, box, colour, width, opacity=1.0):
    """A symbol scaled into the square (x, y, box); `width` = stroke in px."""
    s = box / 12
    return (f'<path d="{GLYPHS[name]}" transform="translate({x:g} {y:g}) scale({s:g})" fill="none" stroke="{colour}" '
            f'stroke-width="{width / s:g}" stroke-linecap="round" stroke-linejoin="round" opacity="{opacity:g}"/>')


def svg(size, body, defs=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            + (f"<defs>{defs}</defs>" if defs else "") + body + "</svg>\n")


# ── small: Sten (16, 24 px) ─────────────────────────────────────────────────
def _k(size):
    return lambda v: round(v * size / 16)


def small_folder(c, size, emblem=None, open_=False):
    p = _k(size)
    body = (f'<path d="M{p(1.5)} {p(3.5)}a1 1 0 0 1 1-1h{p(3.5)}l{p(1.5)} {p(1.5)}h{p(6)}a1 1 0 0 1 1 1V{p(13)}H{p(1.5)}z" fill="{c["back"]}"/>')
    if open_:
        body += f'<rect x="{p(2.5)}" y="{p(4.5)}" width="{p(11)}" height="{p(3)}" fill="{c["paper"]}"/>'
        body += f'<path d="M{p(0.5)} {p(7)}h{p(15)}l-{p(1)} {p(7)}h-{p(13)}z" fill="{c["front"]}"/>'
    else:
        body += f'<rect x="{p(1)}" y="{p(5.5) if size == 16 else p(5.33)}" width="{p(14)}" height="{p(8.5)}" rx="1" fill="{c["front"]}"/>'
    if open_:
        return svg(size, body)
    name = emblem or "fjord"
    box = 7 if size == 16 else 10
    cx, cy = size / 2, (p(5.5) + p(14)) / 2 + (0.5 if size == 16 else 1)
    body += glyph(name, cx - box / 2, cy - box / 2, box, c["deep"], 1 if size == 16 else 1.5, 0.8)
    return svg(size, body)


def small_page(c, size, kind):
    p = _k(size)
    tint = c[TYPE_TINT[kind]] if kind in TYPE_TINT else c["front"]
    body = (f'<path d="M{p(3)} {p(1)}h{p(6.5)}L{p(13)} {p(4.5)}V{p(14)}a1 1 0 0 1-1 1H{p(3)}z" fill="{c["page"]}"/>'
            f'<path d="M{p(9.5)} {p(1)}v{p(3.5)}H{p(13)}z" fill="{c["back"]}"/>'
            f'<rect x="{p(3)}" y="{p(1)}" width="{max(1, p(1.5))}" height="{p(14)}" fill="{tint}"/>')
    box = 7 if size == 16 else 10
    x0 = (p(4.5) + p(13)) / 2 - box / 2
    body += glyph(kind, x0, p(9) - box / 2 + (0.5 if size == 16 else 0), box, c["deep"], 1 if size == 16 else 1.5, 0.75)
    return svg(size, body)


def small_trash(c, size, full=False):
    p = _k(size)
    body = (f'<path d="M{p(3.5)} {p(4.5)}h{p(9)}l-{p(1)} {p(10)}h-{p(7)}z" fill="{c["page"]}"/>'
            f'<rect x="{p(2.5)}" y="{p(3)}" width="{p(11)}" height="{max(1, p(1.5))}" fill="{c["front"]}"/>'
            f'<rect x="{p(6.5)}" y="{p(1.5)}" width="{p(3)}" height="{max(1, p(1.5))}" fill="{c["back"]}"/>')
    for x in (6, 8, 10):
        body += f'<rect x="{p(x) - (0 if size == 16 else 0.5):g}" y="{p(6.5)}" width="1" height="{p(6)}" fill="{c["deep"]}" opacity=".5"/>'
    if full:
        body = body.replace(f'y="{p(3)}"', f'y="{p(3)}" transform="rotate(-8 {p(8)} {p(3.5)})"', 1)
        body = (f'<path d="M{p(4)} {p(4.5)}l{p(2)}-{p(3)} {p(2.5)} {p(1.5)} {p(2)}-{p(1.5)} {p(1.5)} {p(3)}z" fill="{c["paper"]}" stroke="{c["line"]}" stroke-width=".5"/>' + body)
    return svg(size, body)


def small_device(c, size, kind):
    p = _k(size)
    if kind == "computer":
        body = (f'<rect x="{p(1)}" y="{p(2)}" width="{p(14)}" height="{p(9.5)}" rx="1" fill="{c["back"]}"/>'
                f'<rect x="{p(2)}" y="{p(3)}" width="{p(12)}" height="{p(7.5)}" fill="{c["front"]}"/>'
                f'<rect x="{p(6)}" y="{p(11.5)}" width="{p(4)}" height="{p(2)}" fill="{c["deep"]}"/>'
                f'<rect x="{p(4)}" y="{p(13.5)}" width="{p(8)}" height="{max(1, p(1))}" fill="{c["deep"]}"/>')
    elif kind == "network":
        body = (f'<circle cx="{size / 2:g}" cy="{size / 2:g}" r="{p(6.5)}" fill="{c["front"]}"/>'
                + f'<g fill="none" stroke="{c["deep"]}" stroke-opacity=".6"><ellipse cx="{size / 2:g}" cy="{size / 2:g}" rx="{p(2.5)}" ry="{p(6.5)}"/>'
                f'<path d="M{p(1.5)} {size / 2:g}h{p(13)}"/></g>')
    elif kind == "harddisk":
        body = (f'<rect x="{p(1)}" y="{p(4)}" width="{p(14)}" height="{p(8)}" rx="1" fill="{c["page"]}"/>'
                f'<rect x="{p(1)}" y="{p(9)}" width="{p(14)}" height="{p(3)}" rx="1" fill="{c["back"]}"/>'
                f'<rect x="{p(11)}" y="{p(10)}" width="{max(1, p(2))}" height="1" fill="{c["success"]}"/>')
    else:  # removable / usb
        body = (f'<rect x="{p(5.5)}" y="{p(1)}" width="{p(5)}" height="{p(4)}" fill="{c["page"]}"/>'
                f'<rect x="{p(6.5)}" y="{p(2)}" width="1" height="1" fill="{c["deep"]}"/><rect x="{p(8.5)}" y="{p(2)}" width="1" height="1" fill="{c["deep"]}"/>'
                f'<rect x="{p(4)}" y="{p(5)}" width="{p(8)}" height="{p(10)}" rx="1.5" fill="{c["front"]}"/>'
                f'<rect x="{p(4)}" y="{p(12)}" width="{p(8)}" height="{p(3)}" rx="1.5" fill="{c["back"]}"/>')
    return svg(size, body)


# ── large: Norrsken (scalable, drawn on 128) ────────────────────────────────
SHADOW = '<filter id="sh" x="-20%" y="-20%" width="140%" height="160%"><feGaussianBlur stdDeviation="2.2"/></filter>'


def _aurora(c, gid="au", diagonal=True):
    x2, y1 = ("1", "1") if diagonal else ("1", "0")
    return (f'<linearGradient id="{gid}" x1="0" y1="{y1}" x2="{x2}" y2="0"><stop offset="0" stop-color="{c["aurora0"]}"/>'
            f'<stop offset=".55" stop-color="{c["aurora1"]}"/><stop offset="1" stop-color="{c["aurora2"]}"/></linearGradient>')


VEIL = ('<linearGradient id="veil" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".45"/>'
        '<stop offset=".5" stop-color="#fff" stop-opacity=".08"/><stop offset="1" stop-color="#000" stop-opacity=".12"/></linearGradient>')
FRONT = "M10 48a8 8 0 0 1 8-8h92a8 8 0 0 1 8 8v52a8 8 0 0 1-8 8H18a8 8 0 0 1-8-8z"
FRONT_OPEN = "M6 56a8 8 0 0 1 8-8h100a8 8 0 0 1 7.9 9.3l-6.6 44A8 8 0 0 1 107.4 108H20.6a8 8 0 0 1-7.9-6.7l-6.6-44z"
PAGE = "M28 12h50l26 26v70a6 6 0 0 1-6 6H28a6 6 0 0 1-6-6V18a6 6 0 0 1 6-6z"


def large_folder(c, emblem=None, open_=False):
    defs = SHADOW + _aurora(c) + VEIL
    front = FRONT_OPEN if open_ else FRONT
    body = (f'<ellipse cx="64" cy="112" rx="50" ry="6" fill="#000" opacity=".22" filter="url(#sh)"/>'
            f'<path d="M14 26a8 8 0 0 1 8-8h26c3 0 5 1 7 3l6 6h45a8 8 0 0 1 8 8v66H14z" fill="{c["deep"]}"/>'
            f'<rect x="22" y="{26 if open_ else 32}" width="84" height="40" rx="4" fill="{c["paper"]}" opacity=".9"/>'
            f'<path d="{front}" fill="url(#au)"/><path d="{front}" fill="url(#veil)"/>'
            f'<path d="{"M14 48.75h100" if open_ else "M18 41h92a7 7 0 0 1 7 7"}" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="1.5"/>')
    if emblem:
        body += glyph(emblem, 46, 58, 36, "#ffffff", 6, 0.85)
    return svg(128, body, defs)


def large_page(c, kind):
    if kind in TYPE_TINT:
        t = c[TYPE_TINT[kind]]
        band = (f'<linearGradient id="band" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{t}"/>'
                f'<stop offset="1" stop-color="{mix(t, "#ffffff", 0.3)}"/></linearGradient>')
    else:
        band = _aurora(c, "band", diagonal=False)
    defs = SHADOW + band + f'<clipPath id="page"><path d="{PAGE}"/></clipPath>'
    body = (f'<ellipse cx="64" cy="116" rx="38" ry="5" fill="#000" opacity=".22" filter="url(#sh)"/>'
            f'<path d="{PAGE}" fill="#ffffff"/>'
            f'<rect x="22" y="12" width="82" height="22" fill="url(#band)" clip-path="url(#page)" opacity=".9"/>'
            f'<path d="M78 12v20a6 6 0 0 0 6 6h20z" fill="{c["back"]}"/>'
            + glyph(kind, 39, 52, 48, c["ink"], 5, 0.55)
            + f'<path d="{PAGE}" fill="none" stroke="{c["back"]}" stroke-opacity=".25" stroke-width="1.5"/>')
    return svg(128, body, defs)


def large_trash(c, full=False):
    defs = SHADOW + _aurora(c, "au", diagonal=False) + VEIL
    body = (f'<ellipse cx="64" cy="118" rx="36" ry="5" fill="#000" opacity=".22" filter="url(#sh)"/>'
            f'<path d="M30 38h68l-6 72a6 6 0 0 1-6 5.5H42a6 6 0 0 1-6-5.5z" fill="{c["glass"]}"/>'
            f'<path d="M30 38h68l-6 72a6 6 0 0 1-6 5.5H42a6 6 0 0 1-6-5.5z" fill="url(#veil)"/>'
            + "".join(f'<path d="M{x} 50v52" stroke="{c["back"]}" stroke-opacity=".3" stroke-width="4" stroke-linecap="round"/>' for x in (50, 64, 78)))
    lid = (f'<rect x="22" y="26" width="84" height="12" rx="5" fill="url(#au)"/>'
           f'<path d="M52 26v-4a4 4 0 0 1 4-4h16a4 4 0 0 1 4 4v4" fill="none" stroke="{c["deep"]}" stroke-width="5"/>')
    if full:
        body += (f'<path d="M36 38c2-10 10-16 18-12 4-8 16-9 20-1 8-4 16 2 18 13z" fill="{c["paper"]}" stroke="{c["line"]}" stroke-width="1.5"/>'
                 f'<g transform="rotate(-10 64 32) translate(0 -10)">{lid}</g>')
    else:
        body += lid
    return svg(128, body, defs)


def large_device(c, kind):
    defs = SHADOW + _aurora(c) + VEIL
    shadow = '<ellipse cx="64" cy="114" rx="46" ry="5" fill="#000" opacity=".22" filter="url(#sh)"/>'
    if kind == "computer":
        body = (shadow + f'<rect x="10" y="16" width="108" height="72" rx="8" fill="{c["deep"]}"/>'
                f'<rect x="16" y="22" width="96" height="60" rx="4" fill="url(#au)"/><rect x="16" y="22" width="96" height="60" rx="4" fill="url(#veil)"/>'
                f'<path d="M54 88h20l4 16H50z" fill="{c["back"]}"/><rect x="38" y="102" width="52" height="8" rx="4" fill="{c["deep"]}"/>')
    elif kind == "network":
        body = (shadow + '<circle cx="64" cy="62" r="48" fill="url(#au)"/><circle cx="64" cy="62" r="48" fill="url(#veil)"/>'
                f'<g fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="3"><ellipse cx="64" cy="62" rx="20" ry="48"/>'
                f'<path d="M16 62h96M22 38h84M22 86h84"/></g>')
    elif kind == "harddisk":
        body = (shadow + f'<rect x="12" y="36" width="104" height="58" rx="10" fill="{c["glass"]}"/>'
                f'<rect x="12" y="36" width="104" height="58" rx="10" fill="url(#veil)"/>'
                f'<path d="M12 72h104v12a10 10 0 0 1-10 10H22a10 10 0 0 1-10-10z" fill="url(#au)"/>'
                f'<circle cx="98" cy="83" r="4" fill="{c["success"]}"/>')
    else:
        body = (shadow + f'<rect x="46" y="8" width="36" height="30" rx="3" fill="{c["page"]}"/>'
                f'<rect x="54" y="16" width="7" height="7" fill="{c["deep"]}"/><rect x="67" y="16" width="7" height="7" fill="{c["deep"]}"/>'
                f'<rect x="34" y="36" width="60" height="78" rx="12" fill="url(#au)"/><rect x="34" y="36" width="60" height="78" rx="12" fill="url(#veil)"/>'
                f'<path d="M46 37h36" stroke="#fff" stroke-opacity=".7" stroke-width="1.5"/>')
    return svg(128, body, defs)


# ── the theme ─────────────────────────────────────────────────────────────
# name → (context, drawing, aliases). Aliases are symlinks to the same file.
FOLDERS = {
    "folder": (None, ["inode-directory"]),
    "user-home": ("home", ["folder-home"]),
    "user-desktop": ("desktop", ["folder-desktop"]),
    "folder-documents": ("documents", []),
    "folder-download": ("download", ["folder-downloads"]),
    "folder-music": ("music", []),
    "folder-pictures": ("pictures", ["folder-images"]),
    "folder-videos": ("videos", ["folder-video"]),
    "folder-templates": ("templates", []),
    "folder-publicshare": ("publicshare", ["folder-public"]),
    "folder-projects": ("projects", ["folder-development"]),
}
FILE_TYPES = {
    "text": ["text-x-generic", "text-plain", "x-office-document", "text-markdown", "text-x-readme"],
    "code": ["text-x-script", "application-x-shellscript", "text-x-python", "text-x-csrc", "text-x-chdr", "text-x-c++src",
             "text-x-c++hdr", "text-x-java", "text-x-rust", "text-x-go", "text-javascript", "application-javascript",
             "application-json", "application-xml", "text-html", "text-css", "text-x-qml", "application-x-yaml", "application-toml"],
    "image": ["image-x-generic", "image-png", "image-jpeg", "image-webp", "image-gif", "image-svg+xml"],
    "audio": ["audio-x-generic", "audio-mpeg", "audio-flac", "audio-x-wav", "audio-ogg", "audio-x-vorbis+ogg"],
    "video": ["video-x-generic", "video-mp4", "video-x-matroska", "video-webm"],
    "archive": ["package-x-generic", "application-zip", "application-x-tar", "application-x-compressed-tar",
                "application-x-7z-compressed", "application-x-rar", "application-gzip", "application-x-xz-compressed-tar",
                "application-x-bzip-compressed-tar", "application-x-zstd-compressed-tar"],
    "pdf": ["application-pdf"],
    "spreadsheet": ["x-office-spreadsheet", "application-vnd.oasis.opendocument.spreadsheet",
                    "application-vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application-vnd.ms-excel", "text-csv"],
    "presentation": ["x-office-presentation", "application-vnd.oasis.opendocument.presentation",
                     "application-vnd.openxmlformats-officedocument.presentationml.presentation", "application-vnd.ms-powerpoint"],
}
DEVICES = {
    "computer": ["computer", "user-desktop-computer"],
    "network": ["network-workgroup", "network-server", "folder-remote"],
    "harddisk": ["drive-harddisk", "drive-harddisk-system"],
    "removable": ["drive-removable-media", "drive-removable-media-usb", "media-removable", "media-flash"],
}


def icons(c):
    """Yields (context, name, aliases, small(size) -> svg, large svg)."""
    for name, (emblem, aliases) in FOLDERS.items():
        yield ("places", name, aliases, lambda s, e=emblem: small_folder(c, s, e), large_folder(c, emblem))
    yield ("places", "folder-open", ["folder-drag-accept", "folder-visiting"],
           lambda s: small_folder(c, s, open_=True), large_folder(c, open_=True))
    yield ("places", "user-trash", ["trashcan_empty"], lambda s: small_trash(c, s), large_trash(c))
    yield ("places", "user-trash-full", ["trashcan_full"], lambda s: small_trash(c, s, True), large_trash(c, True))
    for kind, names in DEVICES.items():
        yield ("devices", names[0], names[1:], lambda s, k=kind: small_device(c, s, k), large_device(c, kind))
    for kind, names in FILE_TYPES.items():
        yield ("mimetypes", names[0], names[1:], lambda s, k=kind: small_page(c, s, k), large_page(c, kind))


def index_theme(name, inherits):
    dirs = [f"{s}x{s}/{ctx}" for s in SMALL_SIZES for ctx in ("places", "devices", "mimetypes")] + \
           [f"scalable/{ctx}" for ctx in ("places", "devices", "mimetypes")]
    out = ["[Icon Theme]", f"Name={name}",
           "Comment=Generated by Bifrost in the shell's colours (bifrostctl icons generate); rewritten automatically",
           "Hidden=true",
           f"Inherits={','.join(dict.fromkeys([t for t in inherits if t] + ['hicolor']))}",
           "Directories=" + ",".join(dirs), ""]
    for d in dirs:
        size, ctx = d.split("/")
        out += [f"[{d}]", f"Context={ctx.capitalize() if ctx != 'mimetypes' else 'MimeTypes'}"]
        out += (["Size=128", "MinSize=32", "MaxSize=512", "Type=Scalable"] if size == "scalable"
                else [f"Size={size.split('x')[0]}", "Type=Fixed"])
        out.append("")
    return "\n".join(out)


def write_theme(root: Path, name, c, inherits):
    """Draws the whole theme into `root` (an empty directory). Returns the
    number of icon names (aliases included)."""
    count = 0
    for ctx, icon, aliases, small, large in icons(c):
        for size in SMALL_SIZES:
            d = root / f"{size}x{size}" / ctx
            d.mkdir(parents=True, exist_ok=True)
            (d / f"{icon}.svg").write_text(small(size))
            for a in aliases:
                os.symlink(f"{icon}.svg", d / f"{a}.svg")
        d = root / "scalable" / ctx
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{icon}.svg").write_text(large)
        for a in aliases:
            os.symlink(f"{icon}.svg", d / f"{a}.svg")
        count += 1 + len(aliases)
    (root / "index.theme").write_text(index_theme(name, inherits))
    return count
