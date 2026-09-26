# Installation acceptance — 2026-09-26

Tested on current host with isolated empty HOME/XDG directories and no production service activation: copy installation, command links, config/Lua generation, bundled FullBlue extraction/licenses/cache, installed-copy validate and repeat installation preserving existing FullBlue. No packages or host Hyprland files were changed by this test.

Still required on a separate CachyOS SSD:

1. Run installer with documented dependencies; verify first shell start.
2. Verify launcher, bar/frame/dock, CC, Settings, workspace overview and downloaded theme apply.
3. Verify FullBlue in shell and file manager (folders, Documents/Downloads/Pictures, text/archive/image mimetypes, fallback).
4. Check unsupported hardware hides controls; supported battery/backlight/DDC and hotplug reflect actual state.
5. Logout/login, shell restart and reboot; verify persistence and generated config from zero.
6. Check no DMS/Noctalia runtime dependency.
7. Exercise Vivaldi tiled/floating with every panel position, frame and autohide.

This checklist is pending, not a successful clean-SSD test report.
