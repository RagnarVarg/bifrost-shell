.pragma library

// Key combinations between Qt key events, Bifrost's keybind strings
// ("SUPER + SHIFT + Q", as tools/bifrostctl canon_keys writes them) and what
// the Shortcuts page shows.
//   fromEvent({ key, modifiers, nativeScanCode }) → "SUPER + Q" | "" (modifier only)
//   parts("SUPER + code:10") → ["SUPER", "code:10"]

const MODS = ["SUPER", "CTRL", "ALT", "SHIFT"];

// Qt key → keysym name Hyprland binds by. Keys missing here (and shifted
// punctuation, which differs per layout) are recorded by keycode.
const NAMED = {};
function named() {
    if (Object.keys(NAMED).length)
        return NAMED;
    const table = [
        [Qt.Key_Space, "space"], [Qt.Key_Return, "Return"], [Qt.Key_Enter, "KP_Enter"], [Qt.Key_Tab, "Tab"],
        [Qt.Key_Backtab, "Tab"], [Qt.Key_Escape, "Escape"], [Qt.Key_Backspace, "BackSpace"], [Qt.Key_Delete, "Delete"],
        [Qt.Key_Insert, "Insert"], [Qt.Key_Home, "Home"], [Qt.Key_End, "End"], [Qt.Key_PageUp, "Page_Up"],
        [Qt.Key_PageDown, "Page_Down"], [Qt.Key_Left, "left"], [Qt.Key_Right, "right"], [Qt.Key_Up, "up"],
        [Qt.Key_Down, "down"], [Qt.Key_Print, "Print"], [Qt.Key_Comma, "comma"], [Qt.Key_Period, "period"],
        [Qt.Key_Minus, "minus"], [Qt.Key_Plus, "plus"], [Qt.Key_Equal, "equal"], [Qt.Key_Slash, "slash"],
        [Qt.Key_Backslash, "backslash"], [Qt.Key_Semicolon, "semicolon"], [Qt.Key_Apostrophe, "apostrophe"],
        [Qt.Key_BracketLeft, "bracketleft"], [Qt.Key_BracketRight, "bracketright"], [Qt.Key_QuoteLeft, "grave"],
        [Qt.Key_VolumeUp, "XF86AudioRaiseVolume"], [Qt.Key_VolumeDown, "XF86AudioLowerVolume"],
        [Qt.Key_VolumeMute, "XF86AudioMute"], [Qt.Key_MicMute, "XF86AudioMicMute"], [Qt.Key_MediaPlay, "XF86AudioPlay"],
        [Qt.Key_MediaPause, "XF86AudioPause"], [Qt.Key_MediaTogglePlayPause, "XF86AudioPlay"],
        [Qt.Key_MediaNext, "XF86AudioNext"], [Qt.Key_MediaPrevious, "XF86AudioPrev"], [Qt.Key_MediaStop, "XF86AudioStop"],
        [Qt.Key_MonBrightnessUp, "XF86MonBrightnessUp"], [Qt.Key_MonBrightnessDown, "XF86MonBrightnessDown"]
    ];
    for (const [k, n] of table)
        NAMED[k] = n;
    return NAMED;
}

const MODIFIER_KEYS = () => [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R, Qt.Key_CapsLock, Qt.Key_NumLock];
const SHIFT_SAFE = /^(space|Return|KP_Enter|Tab|Escape|BackSpace|Delete|Insert|Home|End|Page_Up|Page_Down|left|right|up|down|Print|XF86.*)$/;

function fromEvent(e) {
    if (MODIFIER_KEYS().indexOf(e.key) >= 0)
        return "";
    const m = e.modifiers;
    const mods = [];
    if (m & Qt.MetaModifier)
        mods.push("SUPER");
    if (m & Qt.ControlModifier)
        mods.push("CTRL");
    if (m & Qt.AltModifier)
        mods.push("ALT");
    if (m & Qt.ShiftModifier)
        mods.push("SHIFT");
    const shift = (m & Qt.ShiftModifier) !== 0;
    const code = e.nativeScanCode || 0;
    let key = "";
    if (code >= 10 && code <= 19)
        key = "code:" + code;                           // digit row, any layout
    else if (e.key >= Qt.Key_A && e.key <= Qt.Key_Z)
        key = String.fromCharCode(e.key);
    else if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F35)
        key = "F" + (e.key - Qt.Key_F1 + 1);
    else if (named()[e.key] && (!shift || SHIFT_SAFE.test(named()[e.key])))
        key = named()[e.key];
    else if (code > 0)
        key = "code:" + code;
    return key ? mods.concat([key]).join(" + ") : "";
}

function parts(keys) {
    return String(keys || "").split("+").map(s => s.trim()).filter(s => s !== "");
}

function isModifier(part) {
    return MODS.indexOf(String(part).toUpperCase()) >= 0 || String(part).toUpperCase() === "CONTROL";
}

// Display text for one part; `tr` translates the few worded ones.
function label(part, tr) {
    const p = String(part);
    const u = p.toUpperCase();
    const words = {
        SUPER: "Super", CTRL: "Ctrl", CONTROL: "Ctrl", ALT: "Alt", SHIFT: "Shift",
        SPACE: tr("Space"), RETURN: "Enter", KP_ENTER: "Enter", TAB: "Tab", ESCAPE: "Esc", BACKSPACE: "⌫",
        DELETE: "Del", PAGE_UP: "PgUp", PAGE_DOWN: "PgDn", LEFT: "←", RIGHT: "→", UP: "↑", DOWN: "↓",
        PRINT: "PrtSc", COMMA: ",", PERIOD: ".", MINUS: "-", PLUS: "+", EQUAL: "=", SLASH: "/", BACKSLASH: "\\",
        SEMICOLON: ";", APOSTROPHE: "'", BRACKETLEFT: "[", BRACKETRIGHT: "]", GRAVE: "`",
        "MOUSE:272": tr("Left click"), "MOUSE:273": tr("Right click"), "MOUSE:274": tr("Middle click"),
        MOUSE_DOWN: tr("Scroll down"), MOUSE_UP: tr("Scroll up"),
        XF86AUDIORAISEVOLUME: tr("Volume up key"), XF86AUDIOLOWERVOLUME: tr("Volume down key"),
        XF86AUDIOMUTE: tr("Mute key"), XF86AUDIOMICMUTE: tr("Mic mute key"), XF86AUDIOPLAY: tr("Play key"),
        XF86AUDIOPAUSE: tr("Pause key"), XF86AUDIONEXT: tr("Next key"), XF86AUDIOPREV: tr("Previous key"),
        XF86AUDIOSTOP: tr("Stop key"), XF86MONBRIGHTNESSUP: tr("Brightness up key"), XF86MONBRIGHTNESSDOWN: tr("Brightness down key")
    };
    if (words[u] !== undefined)
        return words[u];
    const code = /^code:(\d+)$/i.exec(p);
    if (code) {
        const n = Number(code[1]);
        return n >= 10 && n <= 19 ? String((n - 9) % 10) : tr("Key %1").replace("%1", n);
    }
    return p.length === 1 ? u : p;
}

// Lower-case comparison form, like bifrostctl keys_id (modifier order and
// digit keycodes don't matter).
function id(keys) {
    const ps = parts(keys);
    if (!ps.length)
        return "";
    const key = ps[ps.length - 1];
    const mods = MODS.filter(m => ps.slice(0, -1).some(x => x.toUpperCase() === m || (m === "CTRL" && x.toUpperCase() === "CONTROL")));
    const code = /^code:(\d+)$/i.exec(key);
    const k = code && Number(code[1]) >= 10 && Number(code[1]) <= 19 ? String((Number(code[1]) - 9) % 10) : key;
    return mods.concat([k]).join(" + ").toLowerCase();
}
