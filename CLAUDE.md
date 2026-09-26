# Bifrost Shell — instructions for Claude sessions

Bifrost is the user's own Quickshell desktop shell. Since 2026-09-25 it **is** the user's session shell
(bifrost.service; DMS stopped), installed with `install.sh --link` (~/.local/share/bifrost-shell → this repo),
so edits here are live. The user writes in Swedish; answer in Swedish. UI source strings are English
(`I18n.tr`), with the Swedish catalogue in `i18n/sv.json`.

## Read first
1. `docs/HANDOFF.md` — status, what's done, known problems, the exact next step
2. `docs/ARCHITECTURE.md` — layers, config system, tokens, compositor abstraction
3. `docs/INVENTORY.md` — the production setup (read-only for us)
4. `docs/EXTERNAL-APIS.md` — every external API we depend on and its verification status
5. `git log --oneline`

## Hard rules
- Never modify `~/.config/DankMaterialShell/**`, `~/.local/state/DankMaterialShell/**`, `~/.config/quickshell/**`,
  the `dms.service` unit/override, system files or packages. No DMS/Noctalia runtime dependency.
- `~/.config/hypr/**`: only the installer's marked BIFROST_BEGIN/END block in hyprland.lua (with backup). Everything
  Bifrost sets in Hyprland goes through the generated `~/.config/bifrost/hypr/bifrost.lua` (bifrostctl).
- Don't run `hyprctl reload` or window/workspace dispatches against the user's session without asking; test in
  nested mode or a scratch overlay instance (see HANDOFF §4).
- Bifrost writes to this repo, `~/.config/bifrost/`, `$XDG_RUNTIME_DIR/bifrost*/`, `~/.cache/bifrost/`, and — only via
  `bifrostctl appearance apply` with one-time backups — single keys in gsettings, GTK settings.ini and qt5ct/qt6ct.
- No personal paths (/home/<user>, ~/Projects) in anything installed or generated.
- Version-sensitive code lives only in `shell/Compat/` and `shell/Compositor/*Backend.qml`;
  dependencies/min versions only in `dependencies.json`. UI uses the `Compositor` facade + capabilities.
- Every setting goes through `schema/*.json`; every visual value through `themes/_base.json` tokens
  (`Theme.*`). No literal colours/sizes/durations in components.
- `shell/Core/ConfigLogic.js` and `tools/bifrostctl` implement the same semantics — change both. Same for
  config migrations (`Core/Migrations.js` ↔ `bifrostctl migrate`) and schema templates (`Schema.expandTemplate` ↔
  `expand_template`). Bump `Config.formatVersion` and `FORMAT_VERSION` together.
- Every user-visible string goes through `I18n.tr()` (English source) and gets a Swedish entry in `i18n/sv.json`;
  a test fails otherwise.
- Panel sizes come from `Core/Metrics.qml` (density, frame), glass from `Theme.materials.<surface>` (Glass & materials).

## Workflow
- Test: `scripts/selftest.sh` (must pass before committing; ~15 s), `tools/bifrostctl validate`, `tools/bifrostctl doctor`.
- Restart after schema/shader/singleton changes: `systemctl --user restart bifrost.service`; Settings:
  `bifrost-settings` (or `qs ipc -p ~/.local/share/bifrost-shell/shell/settings.qml call settings quit` first).
- Run: `scripts/dev.sh` (overlay mode, Ctrl+C to stop). IPC: `qs ipc -p $PWD/shell call bifrost status`.
  Scratch instance next to production: `BIFROST_CONFIG_DIR=<scratch> BIFROST_RUN_MODE=overlay setsid qs -p $PWD/shell &`,
  then `qs ipc --pid <pid> call …` and `kill <pid>` (never `pkill -f`).
- Gallery: `scripts/gallery.sh` (Esc closes). Screenshot for review: `grim -l 1 <scratch>/shot.png`;
  `BIFROST_GALLERY_SCROLL=<px>` opens it scrolled. Use a scratch `BIFROST_CONFIG_DIR` to try settings
  without touching the user's config.
- Settings: `scripts/settings.sh [section|key]`; drive a running instance with
  `qs ipc -p $PWD/shell/settings.qml call settings open|search|close …` (useful for screenshots).
- Bar dev aids: `BIFROST_DEV_OPEN_TRAY=<index>` opens that tray item's menu at start;
  `qs ipc -p $PWD/shell call bifrost compositor` dumps normalised compositor state.
  Try bar settings live against a scratch `BIFROST_CONFIG_DIR` with `tools/bifrostctl set …`.
- Shortcuts page: `BIFROST_DEV_KEYBINDS="<search>|<id to expand>"` (id `new` = add form) for screenshots; data and edits
  only through `bifrostctl keybinds list|check|set|off|reset|add` (the generator's own catalogue, `keybind_entries`).
- Phase-5 panels: `qs ipc -p $PWD/shell call launcher open|search <q>|close`, `controlcenter toggle|close`,
  `osd preview volume 62`; `BIFROST_DEV_OPEN_DOCK=<index>` opens a dock entry's menu at start.
  Panels with Exclusive keyboard focus (launcher) must be closed again after screenshots.
- Nested testing (`scripts/nested.sh`): find the nested instance with `hyprctl instances -j` (the one that is not
  the host), then target it explicitly: `HYPRLAND_INSTANCE_SIGNATURE=<nested> hyprctl …`,
  `WAYLAND_DISPLAY=<nested socket> qs ipc -p $PWD/shell call …` / `grim -o WAYLAND-1`, and
  `DBUS_SESSION_BUS_ADDRESS=<from /proc/<pid>/environ> notify-send …`. Stop it by killing its pid.
  Window actions (`wm` IPC) may only ever be run against the nested instance.
- Real pointer motion (hover) in nested: `scripts/vpointer.sh W H` (wlr virtual pointer, commands on stdin:
  move/glide/click/scroll/sleep) and `tools/dev/hovertest.py [--via-popup] [--only ids]` (every bar popup → every
  other, via IPC `bar widgets`). Both need WAYLAND_DISPLAY/HYPRLAND_INSTANCE_SIGNATURE of the nested instance —
  against the session they move the user's cursor.
- Data operations (presets, profiles, bundles, DMS import) live only in `tools/bifrostctl`; QML calls it via
  `Core/Ctl.qml` with `--json`. Never write DMS files; `import-dms` only reads them.
- Edit QML with in-place writes (Edit/Write tools or Python), not `sed -i`: sed replaces the file and Quickshell's
  watcher loses it, so a running instance does not reload (force with `qs ipc … call bifrost reload`).
  Schema JSON is read at start only; restart Settings/shell after schema changes.
- IPC function names `show` don't work (arguments rejected); pick another name.
- Never name a QML singleton after a QtQuick type (`State`, `Item`, …): it is silently shadowed.
- Selftest never instantiates window modules (they would open real windows); it only checks they compile.
- Bar widgets: set `shown`, never `visible`, on the widget root; register new widgets in `WidgetHost.components`
  and `schema/widgets.json`, and add them to `testBar` in the selftest.
- Side bars (bar.position left/right) are the top/bottom bar turned 90°: widgets must support `vertical` (lay out with
  `Widgets/BarRow`, give their length along the bar as `implicitHeight`, no anchors on BarRow children). Never use
  `Region { item }` for anything inside the turned `BarWindow.view`; map both corners (`windowRect`, `MenuHost.rectIn`).
- Panels placed relative to the bar use `Metrics.barEdge` / `edgeSpace()` / `panelInset()`, never `bar.position` directly.
- New Settings editors: add a component in `shell/Settings/Editors/` and register it in `SettingRow.editors`
  (URL loading fails silently in Quickshell), and add a selftest case in `testEditors`.
- Shaders: edit `shell/Components/Shaders/*.frag`, then `scripts/build-shaders.sh`.
- One commit per working step, trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or the current model).
- Update `docs/HANDOFF.md` after each larger phase.
