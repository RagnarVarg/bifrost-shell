#!/usr/bin/env bash
# Bifrost Shell installer (per user, no root needed except for the optional
# greetd login screen).
#
#   ./install.sh                 install/update into ~/.local/share/bifrost-shell
#   ./install.sh --install-deps install Fedora/Ubuntu dependencies (sudo; shows plan)
#   ./install.sh --deps-plan    preview package/repository changes without writing
#   ./install.sh --link          development: the install dir is a symlink to
#                                this checkout, so edits apply live
#   ./install.sh --yes           answer yes to every question (unattended)
#   ./install.sh --no-hypr       don't hook bifrost.lua into hyprland.lua
#   ./install.sh --no-greeter    don't offer the greetd login screen
#   ./install.sh --no-enable     install the service but don't enable it
#   ./install.sh --uninstall     remove what the installer added (config kept)
#
# What it does:
#   1. copies Bifrost to $XDG_DATA_HOME/bifrost-shell (or links it with --link)
#   2. links the commands (bifrost-ipc, bifrost-settings, bifrost-terminal,
#      bifrost-screenshot, bifrost-shell, bifrostctl) into ~/.local/bin
#   3. installs the systemd user service bifrost.service
#   4. writes ~/.config/bifrost/hypr/bifrost.lua (keybindings, window look,
#      displays) and, after asking, loads it at the end of hyprland.lua
#   5. installs the bundled FullBlue icon theme
#   6. adds a "Bifrost Settings" desktop entry
#   7. if greetd is present, offers to install the Bifrost login screen
#      (asks, needs sudo; never with --yes). Switching greetd over to it stays a
#      separate step: sudo greeter/install-greeter.sh --enable
# Nothing of DMS or Noctalia is used or needed.
set -euo pipefail

src="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
dest="${BIFROST_DIR:-$data_home/bifrost-shell}"
bin_dir="$HOME/.local/bin"
unit_dir="$config_home/systemd/user"
hypr_lua="$config_home/hypr/hyprland.lua"
hook_begin="-- BIFROST_BEGIN (added by the Bifrost installer; remove this block to unhook)"
hook_end="-- BIFROST_END"
hook_load='dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/bifrost/hypr/bifrost.lua")'

link=0 yes=0 hypr=1 greeter=1 enable=1 uninstall=0 install_deps=0 deps_plan=0
for a in "$@"; do
    case "$a" in
        --link) link=1 ;;
        --install-deps) install_deps=1 ;;
        --deps-plan) deps_plan=1 ;;
        --yes|-y) yes=1 ;;
        --no-hypr) hypr=0 ;;
        --no-greeter|--no-sddm) greeter=0 ;;
        --no-enable) enable=0 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) sed -n '2,29p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 2 ;;
    esac
done

if ((uninstall && (install_deps || deps_plan) || install_deps && deps_plan)); then
    echo "--uninstall, --install-deps and --deps-plan cannot be combined" >&2
    exit 2
fi

say() { printf '\033[1m::\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
ask() {
    ((yes)) && return 0
    [[ -t 0 ]] || return 1
    local r
    read -r -p "   $1 [y/N] " r
    [[ "$r" =~ ^[YyJj] ]]
}

commands=(bifrost-ipc bifrost-settings bifrost-terminal bifrost-screenshot bifrost-shell)

unhook_hypr() {
    [[ -f "$hypr_lua" ]] && grep -qF -- "$hook_begin" "$hypr_lua" || return 0
    cp -a "$hypr_lua" "$hypr_lua.before-bifrost-unhook.$(date +%s)"
    python3 - "$hypr_lua" "$hook_begin" "$hook_end" <<'EOF'
import sys
path, begin, end = sys.argv[1:]
out, skip = [], False
for line in open(path).read().split("\n"):
    if line == begin: skip = True; continue
    if skip and line == end: skip = False; continue
    if not skip: out.append(line)
open(path, "w").write("\n".join(out).rstrip("\n") + "\n")
EOF
    say "removed the Bifrost hook from $hypr_lua"
}

if ((uninstall)); then
    systemctl --user disable --now bifrost.service 2>/dev/null || true
    rm -f "$unit_dir/bifrost.service" "$unit_dir/bifrost-session.target"
    systemctl --user daemon-reload 2>/dev/null || true
    for c in "${commands[@]}" bifrostctl; do
        [[ -L "$bin_dir/$c" ]] && rm -f "$bin_dir/$c"
    done
    rm -f "$data_home/applications/bifrost-settings.desktop" "$data_home/applications/bifrost.shell.desktop" "$data_home/applications/bifrost.settings.desktop"
    unhook_hypr
    rm -rf "$dest"
    say "Bifrost removed. Your settings are still in $config_home/bifrost."
    exit 0
fi

# ── 0. dependencies ──────────────────────────────────────────────────────
command -v python3 >/dev/null || { warn "Install python3 first (dnf install python3 / apt install python3)."; exit 1; }
if ((deps_plan)); then
    exec python3 "$src/tools/dependencies.py" --plan
fi
if ((install_deps)); then
    dep_args=(--install)
    ((yes)) && dep_args+=(--yes)
    python3 "$src/tools/dependencies.py" "${dep_args[@]}"
fi
# Check actual binaries/modules before changing any installed user files.
python3 "$src/tools/dependencies.py" --check
if ((hypr)) && [[ ! -f "$hypr_lua" && -f "${hypr_lua%.lua}.conf" ]]; then
    warn "Existing hyprland.conf found. Convert it to Lua first, or use --no-hypr to install without changing it."
    exit 1
fi

# ── 1. files ─────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$dest")"
if ((link)); then
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        mv "$dest" "$dest.before-link.$(date +%s)"
    fi
    ln -sfn "$src" "$dest"
    say "linked $dest → $src (development install)"
elif [[ "$(readlink -f "$dest" 2>/dev/null)" == "$src" ]]; then
    say "running from the install dir itself; files are in place"
else
    [[ -L "$dest" ]] && rm -f "$dest"
    mkdir -p "$dest"
    rsync -a --delete --exclude .git --exclude '__pycache__' "$src/" "$dest/"
    say "installed files into $dest"
fi

# ── 2. commands ──────────────────────────────────────────────────────────
mkdir -p "$bin_dir"
for c in "${commands[@]}"; do
    ln -sfn "$dest/bin/$c" "$bin_dir/$c"
done
ln -sfn "$dest/tools/bifrostctl" "$bin_dir/bifrostctl"
say "commands linked into $bin_dir"
case ":$PATH:" in *":$bin_dir:"*) ;; *) warn "$bin_dir is not on your PATH (keybindings don't need it)";; esac

# ── 3. systemd user service ──────────────────────────────────────────────
mkdir -p "$unit_dir"
cp "$dest/systemd/bifrost-session.target" "$unit_dir/bifrost-session.target"
exec_path="$dest/bin/bifrost-shell"
[[ "$exec_path" == "$HOME/"* ]] && exec_path="%h/${exec_path#"$HOME/"}"
sed "s|@EXEC@|$exec_path|" "$dest/systemd/bifrost.service" >"$unit_dir/bifrost.service"
systemctl --user daemon-reload 2>/dev/null || true
if ((enable)); then
    systemctl --user enable bifrost.service >/dev/null 2>&1 && say "bifrost.service enabled (starts with the graphical session)"
fi

# ── 4. Hyprland integration ──────────────────────────────────────────────
"$dest/tools/bifrostctl" hypr generate --write
if ((hypr)) && [[ ! -e "$hypr_lua" ]]; then
    if ask "Create a minimal Hyprland Lua configuration for this new installation?"; then
        mkdir -p "$(dirname "$hypr_lua")"
        printf '%s\n%s\n%s\n%s\n%s\n' "$hook_begin" \
            'hl.config({ autogenerated = false })' \
            'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })' \
            "$hook_load" "$hook_end" > "$hypr_lua"
    fi
fi
if ((hypr)) && [[ -f "$hypr_lua" ]]; then
    if grep -qF "bifrost/hypr/bifrost.lua" "$hypr_lua"; then
        # Upgrade only our own legacy hook; leave hand-written hooks alone.
        python3 - "$hypr_lua" "$hook_begin" "$hook_end" "$hook_load" <<'EOF'
import pathlib, shutil, sys, time
path = pathlib.Path(sys.argv[1])
begin, end, load = sys.argv[2:]
text = path.read_text()
old = 'dofile(os.getenv("HOME") .. "/.config/bifrost/hypr/bifrost.lua")'
legacy = begin + "\n" + old + "\n" + end
updated = text.replace(legacy, begin + "\n" + load + "\n" + end)
if updated != text:
    shutil.copy2(path, str(path) + ".before-bifrost." + str(time.time_ns()))
    path.write_text(updated)
EOF
        say "hyprland.lua already loads bifrost.lua"
    elif ask "Load Bifrost's keybindings and window settings from $hypr_lua? (a backup is made)"; then
        cp -a "$hypr_lua" "$hypr_lua.before-bifrost.$(date +%s)"
        # An older hand-made Bifrost binds module duplicates keys; turn it off.
        sed -i -E 's|^(\s*)(require\("config\.bifrost-binds"\))|\1-- \2  -- replaced by bifrost.lua (BIFROST_BEGIN below)|' "$hypr_lua"
        printf '\n%s\n%s\n%s\n' "$hook_begin" "$hook_load" "$hook_end" >>"$hypr_lua"
        say "hooked bifrost.lua into $hypr_lua (Hyprland reloads it by itself)"
    else
        say "not hooked. To do it yourself, add to the end of hyprland.lua:"
        echo "     $hook_load"
    fi
elif ((hypr)); then
    warn "no $hypr_lua (Hyprland with a Lua config, 0.55+). Keybindings are in $config_home/bifrost/hypr/bifrost.lua"
fi

# ── 5. bundled default icons (offline, checksum verified) ────────────────
python3 "$dest/scripts/install-icons.py" --icons-dir "$data_home/icons"

# ── 6. desktop entry ─────────────────────────────────────────────────────
mkdir -p "$data_home/applications"
cat >"$data_home/applications/bifrost-settings.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bifrost Settings
Comment=Settings for the Bifrost desktop shell
Exec=$dest/bin/bifrost-settings
Icon=preferences-desktop
Categories=Settings;DesktopSettings;
StartupWMClass=bifrost.settings
EOF

# Qt's host portal registration resolves the exact QML AppId as a desktop ID.
cat >"$data_home/applications/bifrost.shell.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Bifrost Shell
Exec=$dest/bin/bifrost-shell
Icon=preferences-desktop
NoDisplay=true
EOF
cp "$data_home/applications/bifrost-settings.desktop" "$data_home/applications/bifrost.settings.desktop"
printf 'NoDisplay=true\n' >>"$data_home/applications/bifrost.settings.desktop"

# ── 7. greetd login screen ───────────────────────────────────────────────
# Installing only copies files to /usr/share/bifrost-greeter; greetd keeps its
# current greeter until --enable. Needs sudo, so it is never done under --yes.
greeter_sh="$dest/greeter/install-greeter.sh"
if ((greeter)) && [[ -x "$greeter_sh" ]] && { command -v greetd >/dev/null || [[ -d /etc/greetd ]]; }; then
    if ((yes)); then
        say "greetd found. Login screen (needs sudo): sudo $greeter_sh"
    elif ask "Install or update the Bifrost login screen for greetd (needs sudo; greetd itself is not switched)?"; then
        if sudo "$greeter_sh"; then
            "$dest/tools/bifrostctl" greeter sync || warn "login screen installed, but copying your look failed"
        else
            warn "login screen not installed"
        fi
    fi
    if ! grep -qF bifrost-greeter /etc/greetd/config.toml 2>/dev/null; then
        say "greetd does not use the Bifrost login screen. Switch with: sudo $greeter_sh --enable"
    fi
fi

say "done. Start now with: systemctl --user start bifrost.service   (stops DMS if it runs: Conflicts=)"
