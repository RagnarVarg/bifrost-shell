#!/usr/bin/env bash
# Bifrost login screen (greetd) – install, switch on, switch off.
#
#   sudo greeter/install-greeter.sh             copy the login screen to /usr/share/bifrost-greeter
#                                               and create /var/cache/bifrost-greeter. greetd is NOT touched.
#   bifrostctl greeter sync                     (as yourself) copy your look, wallpaper, picture, keyboard.
#   sudo greeter/install-greeter.sh --enable    greetd uses it from the next login screen on
#                                               (backs up /etc/greetd/config.toml first).
#   sudo greeter/install-greeter.sh --disable   put the previous greeter back (latest backup).
#   greeter/install-greeter.sh --status         what greetd uses now.
#   sudo greeter/install-greeter.sh --uninstall --disable, then remove /usr/share/bifrost-greeter.
#
# Safety: bifrost-greeter starts dms-greeter by itself whenever the Bifrost
# login screen ends without a login (missing files, a crash). If the screen is
# ever black anyway: Ctrl+Alt+F2, log in, run --disable, then
#   sudo systemctl restart greetd
#
# Paths can be pointed elsewhere for testing: BIFROST_GREETER_PREFIX,
# BIFROST_GREETER_CACHE, GREETD_CONFIG, GREETER_USER.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
prefix="${BIFROST_GREETER_PREFIX:-/usr/share/bifrost-greeter}"
cache="${BIFROST_GREETER_CACHE:-/var/cache/bifrost-greeter}"
conf="${GREETD_CONFIG:-/etc/greetd/config.toml}"
guser="${GREETER_USER:-greeter}"
launcher="$prefix/bin/bifrost-greeter"

say() { printf '%s\n' "$*"; }
die() { printf 'install-greeter: %s\n' "$*" >&2; exit 1; }
as_root() { [[ $(id -u) -eq 0 || -n "${BIFROST_GREETER_PREFIX:-}" ]] || die "run with sudo"; }

current_command() {
    [[ -r "$conf" ]] || return 0
    awk '/^\[default_session\]/{s=1; next} /^\[/{s=0} s && /^[[:space:]]*command[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/, ""); print; exit}' "$conf"
}

install_files() {
    as_root
    [[ -r "$repo/shell/greeter.qml" ]] || die "run from a Bifrost checkout ($repo)"
    say "Copying the login screen to $prefix"
    local tmp="$prefix.new"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    for d in shell schema themes presets i18n assets greeter; do
        cp -r "$repo/$d" "$tmp/"
    done
    cp "$repo/dependencies.json" "$tmp/"
    mkdir -p "$tmp/bin"
    cp "$repo/greeter/bin/bifrost-greeter" "$tmp/bin/"
    chmod 755 "$tmp/bin/bifrost-greeter" "$tmp/greeter/session.sh"
    find "$tmp" -name '*.qmlc' -delete
    chmod -R a+rX "$tmp"
    rm -rf "$prefix.old"
    [[ -e "$prefix" ]] && mv "$prefix" "$prefix.old"
    mv "$tmp" "$prefix"
    rm -rf "$prefix.old"

    say "Preparing $cache (group $guser; your account copies into it)"
    mkdir -p "$cache/state"
    if [[ $(id -u) -eq 0 ]]; then
        chown root:"$guser" "$cache"
        chmod 2775 "$cache"
        chown "$guser":"$guser" "$cache/state"
        chmod 0770 "$cache/state"
    fi
    say ""
    say "Installed. greetd is unchanged. Next:"
    say "  1. bifrostctl greeter sync          (as yourself; also automatic when your look changes)"
    say "  2. sudo $0 --enable"
    local me="${SUDO_USER:-}"
    if [[ -n "$me" ]] && ! id -nG "$me" | tr ' ' '\n' | grep -qx "$guser"; then
        say "  Note: $me is not in group $guser, so the copy cannot be written: sudo usermod -aG $guser $me (then log in again)"
    fi
}

enable() {
    as_root
    [[ -x "$launcher" ]] || die "not installed yet (run without options first)"
    [[ -w "$conf" ]] || die "cannot write $conf"
    local cmd; cmd="$(current_command)"
    if [[ "$cmd" == *"$launcher"* ]]; then
        say "Already enabled: $cmd"
        return
    fi
    [[ -x /usr/bin/dms-greeter ]] || say "Warning: /usr/bin/dms-greeter (the automatic fallback) is not installed."
    local backup; backup="$conf.before-bifrost-$(date +%Y%m%d-%H%M%S)"
    cp -p "$conf" "$backup"
    awk -v cmd="command = \"$launcher\"" '
        /^\[default_session\]/ { s = 1; print; next }
        /^\[/ { s = 0 }
        s && /^[[:space:]]*command[[:space:]]*=/ { print cmd; done = 1; next }
        { print }
        END { if (!done) exit 3 }' "$backup" > "$conf.tmp" || { rm -f "$conf.tmp"; die "no command in [default_session] of $conf; nothing changed"; }
    cat "$conf.tmp" > "$conf"
    rm -f "$conf.tmp"
    say "Enabled. Backup: $backup"
    say "Was: $cmd"
    say "Now: $(current_command)"
    say "It shows from the next login screen (log out, or reboot). To undo: sudo $0 --disable"
}

disable() {
    as_root
    local backup; backup="$(ls -1t "$conf".before-bifrost-* 2>/dev/null | head -1 || true)"
    local cmd; cmd="$(current_command)"
    if [[ "$cmd" != *"bifrost-greeter"* ]]; then
        say "Not enabled (greetd uses: $cmd). Nothing changed."
        return
    fi
    [[ -n "$backup" ]] || die "no backup ($conf.before-bifrost-*) found; set command in $conf by hand"
    cat "$backup" > "$conf"
    say "Disabled: restored $backup"
    say "greetd uses: $(current_command)"
    say "It shows from the next login screen (or now: sudo systemctl restart greetd – ends running sessions)."
}

status() {
    say "greetd config:   $conf"
    say "greetd uses:     $(current_command)"
    say "installed:       $([[ -x "$launcher" ]] && echo "yes ($prefix)" || echo no)"
    say "cache:           $([[ -d "$cache" ]] && echo "$cache" || echo "missing")"
    say "last copy:       $([[ -r "$cache/greeter.json" ]] && date -r "$cache/greeter.json" '+%F %T' || echo never)"
    say "fallback:        $([[ -x /usr/bin/dms-greeter ]] && echo "dms-greeter installed" || echo "dms-greeter MISSING")"
    local log="/run/user/$(id -u "$guser" 2>/dev/null || echo 0)/bifrost-greeter/fallback.log"
    [[ -r "$log" ]] && { say "fallback log:"; tail -5 "$log"; }
    return 0
}

case "${1:-install}" in
    install) install_files ;;
    --enable) enable ;;
    --disable) disable ;;
    --status) status ;;
    --uninstall)
        disable || true
        as_root
        rm -rf "$prefix"
        say "Removed $prefix (the cache $cache is kept)."
        ;;
    -h|--help) sed -n '2,22p' "$0" ;;
    *) die "unknown option $1 (see --help)" ;;
esac
