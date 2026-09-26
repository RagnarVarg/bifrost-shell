# Inventering av nuvarande setup (production)

Läst 2026-09-24. **Ingenting i denna setup ändras av Bifrost.**

## Versioner

| Komponent | Version | Källa |
|---|---|---|
| Hyprland | 0.56.2 (**Lua-config**, `hyprland.lua`) | pacman `hyprland` |
| Quickshell | 0.3.1 | pacman `quickshell` |
| DMS (DankMaterialShell) | v1.6.1 (`dms-shell`) | pacman, Go-binär `/usr/bin/dms` |
| Session | greetd → uwsm → `start-hyprland` | `greetd-dms-greeter-bin` |
| Monitor | DP-2, 5120×1440 @ 240 Hz, scale 1, 10-bit | `hypr/dms/outputs.lua` |

## Vad är vad

### Hyprland (kompositor) — `~/.config/hypr/`
- `hyprland.lua` — huvudfil. Egen input/gaps/decoration/blur/animationer/window rules.
- `dms/*.lua` — **genereras av DMS** (colors, outputs, layout, cursor, binds, windowrules). `binds-user.lua` är dina egna overrides (gestures, wallpaper-selector, window-switcher).
- `config/*.lua` — delvis aktiva: bara `resize-border`, `floatmode`, `floatmode-workspace`, `border-colors`, `mpv-on-top` är `require`:ade. Övriga (`binds`, `autostart` som startar `noctalia`, m.fl.) kommer från `cachyos-hypr-noctalia` och **laddas inte**.
- `scripts/` — egna skript (floatmode, window-switcher.py + rofi, `snap-preview/shell.qml`).
- Blur: `size 3, passes 2`, ingen vibrancy — redan "klart glas"-riktning.

### DMS (shell) — körs som `dms.service` (systemd user)
- `dms run --session` → startar `qs -p ~/.config/DankMaterialShell/shell`.
- Override `~/.config/systemd/user/dms.service.d/override.conf` sätter `DMS_SHELL_DIR` till en **lokal fork** av QML-trädet (forkad 2026-09-19), samt `TimeoutStartSec=300s`.
- DMS äger idag dessa **singleton-resurser** i sessionen:
  - D-Bus `org.freedesktop.Notifications` (notification-server)
  - Polkit-agent
  - Session lock (lock screen)
  - Wallpaper (lager `quickshell`, 5120×1440, background)
  - Bar (`dms:bar`, exklusiv zon 36 px) och dock (`dms:dock`)
  - Keybinds via `dms ipc call …` i `hypr/dms/binds.lua`
- Konfig:
  - `~/.config/DankMaterialShell/settings.json` — ~609 inställningar i DMS-modellen (`Common/SettingsData.qml`), configVersion 18
  - `~/.local/state/DankMaterialShell/session.json` — wallpaperPath, väderkoordinater, pinnade dock-appar, dolda appar
  - `~/.config/DankMaterialShell/themes/*/theme.json` — 11 färgteman (aktivt: **nord**, custom)
  - `~/.cache/DankMaterialShell/` — färgcache, notifikationshistorik, launcher-cache
- Greeter: `greetd-dms-greeter-bin` (utanför Bifrosts scope initialt).

### Övriga komponenter
- `~/.config/quickshell/wallpaper-selector/` — fristående Quickshell-app (SUPER+W), använder `awww`.
- `awww` (wallpaper-daemon), `matugen`, `cliphist`, `hyprlock` (installerad, oanvänd — DMS låser), `cava`.
- Noctalia 5.1 är installerad men körs inte (`~/.config/noctalia/config.toml` finns kvar).
- Tillgängliga CLI: `nmcli`, `bluetoothctl`, `brightnessctl`, `wpctl`, `upower`, `playerctl`, `jq`.
- Ikonteman: YAMIS (aktiv), Tela-circle, Nordzy, Zafiro, Papirus-liknande m.fl. Font: JetBrainsMono Nerd Font (Inter saknas).

## Quickshell-moduler tillgängliga (0.3.1)
`Hyprland`, `Wayland` (layershell, session lock), `Io`, `Widgets`, `DBusMenu`, `Bluetooth`, `Networking`,
`Services.{Notifications, SystemTray, Mpris, Pipewire, UPower, Pam, Polkit, Greetd}`.

→ Nästan allt Bifrost behöver finns nativt. **Inget beroende av `dms`-binären behövs.**

## Vad från DMS kan återanvändas utan hårt beroende

Endast via en **engångs-import** (read-only), aldrig runtime-länk:

| DMS-källa | → Bifrost |
|---|---|
| `session.json` `wallpaperPath` | `wallpaper.path` |
| `session.json` `weatherCoordinates`, `weatherLocation` | `clock.weather.location` |
| `session.json` `pinnedApps`, `hiddenApps` | `dock.pinned`, `launcher.hidden` |
| `settings.json` `cornerRadius`, transparenser, `blur*` | `appearance.*` |
| `settings.json` `barConfigs[0]` (position, autoHide, spacing, widgets) | `bar.*` (widget-id:n mappas via tabell) |
| `settings.json` `dock*` | `dock.*` |
| `settings.json` `showWeekNumber`, `osd*`, `iconTheme*` | motsvarande |
| `themes/*/theme.json` (primary/surface/outline…) | Bifrost-tema (konverterare) |

DMS QML-kod kopieras inte. Den används bara som referens för vilka funktioner Settings ska täcka.

## Tillägg 2026-09-24 (fas 1)

- Hyprland 0.56 med Lua-config: `hyprctl dispatch <x>` tolkas som `hl.dispatch(<x>)`; klassisk
  dispatch-syntax fungerar inte. `hyprctl eval` finns och används av Bifrost för runtime-only layer rules.
- Quickshell 0.3.1 exponerar `Hyprland.usingLua`.
- Geist/Geist Mono finns bara i AUR (`ttf-geist-variable`, `ttf-geist-mono-variable`); inte installerade.
