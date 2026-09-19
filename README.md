# Bifröst Shell

A beginner-friendly, trackpad-first Hyprland desktop built on DankMaterialShell, with custom gestures, workspace previews, a wallpaper carousel and Gruvbox styling.

Bifröst provides a starting point for people new to Hyprland: a coordinated bar, dock, theme and gesture configuration that you can explore and adapt instead of building everything from scratch. It is a collection of dotfiles, assets and customized shell code, not a Linux distribution.

## Included

- Customized DankMaterialShell 1.6.1, including the bar, dock and workspace overview.
- Gruvbox Multi (material-hard-dark, blue accent), Gruvbox-Plus-Light icons and Bibata Modern Ice cursors.
- Bundled Inter, Fira Code Nerd Font and Material Symbols panel fonts.
- Workspace previews: scroll with two fingers; click a workspace to switch. Browsing does not change the active workspace.
- **Super+W wallpaper carousel:** two-finger scrolling, narrow cards progressively smaller away from the center, one click to choose, and click outside to close.
- 15 decorative wallpapers, with embedded metadata removed.
- Latest exported edge-snap configuration: preview while dragging a floating window, half-screen placement on release and restoration of its saved floating size when dragged again. Mouse and three-finger gesture paths are present. Only the dragged window is changed.
- A per-workspace floating/tiling script, separate from the existing global keyboard shortcut.

No session history, location data, clipboard, notes, accounts, credentials, browser profiles or unrelated home files are included. The local Mac sound pack is excluded.

## Trackpad and shortcuts

| Input | Action |
|---|---|
| Three-finger drag | Move floating windows with snap preview; directional rearrangement for tiled windows |
| Four fingers up | Toggle the current window between floating and tiling |
| Four fingers down | Close the current window |
| Four fingers left/right | Switch workspace |
| Four-finger pinch together | Open workspace overview |
| Four-finger pinch apart | Close workspace overview |
| Super+Tab | Visible window switcher, most recently used first |
| Super+Shift+Tab | Open the window switcher backwards |
| Super+O | Workspace overview |
| Super+W | Wallpaper carousel |
| Super+Shift+Space | Existing **global** floating/tiling toggle |
| Super + left mouse drag | Move a window; snap-aware for floating windows |

Tap-to-click, natural scrolling and `drag_lock = 1` are enabled. Do not run the old external `three-finger-drag.service` alongside these gestures. Alt+Tab is not configured in this export.

The custom three-finger handler uses real start/update/finish callbacks. For tiled windows it rearranges on release rather than reproducing the original built-in move animation.

To toggle only the active workspace:

```bash
bash "$HOME/.config/hypr/scripts/workspace-floatmode-toggle.sh"
```

The script records which windows it floated and restores those on toggling back. New windows follow that workspace's generated rule; other workspaces retain their own rules.

## Window switcher

Hold Super and press Tab to display running windows with application icons and titles. Continue with Tab or the arrow keys; Shift+Tab moves backwards. Release Super or press Enter to select, or Escape to cancel. Overview remains on Super+O and the four-finger pinch gesture.

Rofi uses `-global-kb` to request that compositor shortcuts be inhibited while the picker is open. The latest keyboard-capture correction is included; physical keyboard navigation on the source system still awaits user confirmation. Default Tab bindings are cleared to avoid duplicate-binding errors. Window titles and addresses are kept in memory and are not saved.

## Requirements

Developed on **CachyOS, Magic Trackpad and a 5120×1440 display**. Other distributions, devices and resolutions have not been fully tested.

Reference versions: **Hyprland 0.56.2 with native Lua configuration**, **DMS 1.6.1** (shell revision `19a5eee1e217e936`), **Qt 6.11.2**, **libinput 1.31.3**. These are reference versions, not a claim of compatibility with all newer releases.

Install these before applying the configuration:

- Hyprland with the Lua `hl.*` API, including gesture lifecycle callbacks.
- DankMaterialShell (`dms`) and its runtime dependencies.
- Quickshell (`qs` and `quickshell`) with Qt Quick, Qt5Compat and the modules required by DMS.
- Git, Python 3, Bash, jq and ImageMagick (including the `convert` compatibility command used by the thumbnail script).
- A working systemd user session and D-Bus environment.
- Rofi with Wayland support (configured with Rofi 2.0.0) for the window switcher.
- Kitty for the default terminal shortcut; `notify-send` for toggle notifications.
- Adwaita icons/fonts and Noto as system fallback resources.

The shell's optional controls (audio, brightness, updates, networking, etc.) also depend on the relevant DMS/system services being available. This installer does not set up an operating system or install packages.

## Install on a fresh CachyOS system

```bash
git clone https://github.com/RagnarVarg/bifrost-shell.git
cd bifrost-shell

# Preview only: makes no changes
python3 install.py

# Copy configuration and assets, backing up files being replaced
python3 install.py --apply
```

Existing files are backed up under `~/.local/state/cachyos-shell-config/backups/`. The default monitor profile uses the display's preferred mode. For a matching **DP-2, 5120×1440, approximately 240 Hz** setup, use `--ultrawide` with `--apply`.

After installation:

1. If installed, disable the old external gesture tool with `sudo systemctl disable --now three-finger-drag.service`.
2. Run `systemctl --user daemon-reload`, then `systemctl --user enable --now dms.service`. Restart it if it was already running. The supplied override selects the customized shell directory.
3. Run `hyprctl reload` and then `hyprctl configerrors`.
4. Log out and back in to run the dedicated snap-preview startup hook. For the current session only, start it manually with `qs -n -d -p "$HOME/.config/hypr/scripts/snap-preview/shell.qml"` if it is not already running.
5. Choose a wallpaper with Super+W.

Alternative manual DMS launch: `dms -c "$HOME/.config/DankMaterialShell/shell" run`. Do not run another DMS instance alongside the service.

The installer does not enable services, restart the desktop or install dependencies automatically. To test copying in isolation, use `python3 install.py --apply --target /tmp/bifrost-test`.

## Portability and current limitations

- Home-directory placeholders are substituted at installation. Snap preview uses `XDG_RUNTIME_DIR`, not a fixed user ID.
- A dedicated preview startup module is included because the source desktop's older `autostart.lua` was not loaded. Unrelated legacy autostart commands are excluded.
- The manual bar padding is tuned for ultrawide and needs adjustment on smaller screens.
- Edge snapping uses a fixed **2 px border**; update its `BORDER_SIZE` constant if changing that setting. The source configuration targets a scale-1 monitor at position 0,0. Mixed scaling, rotation and multi-monitor preview coordinates need further testing.
- Saved pre-snap sizes are held in compositor memory, not persisted across login sessions.
- This is a snapshot of customized DMS code. Future DMS updates may require manually merging changes.

## Validation

The export is reviewed for private paths and common credential patterns. Installation is tested in a separate directory, including backup behavior, required Lua module paths and script syntax. Edge-snap callbacks are covered by a mocked Lua regression test (`lua tests/edge-snap.lua`). These checks do not replace physical trackpad testing on the destination computer.

## Credits and licenses

Built on [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell), Hyprland and Quickshell. Original third-party notices and font/icon licenses are retained; see `THIRD_PARTY.md`. No new blanket license is applied to third-party wallpapers or assets.
