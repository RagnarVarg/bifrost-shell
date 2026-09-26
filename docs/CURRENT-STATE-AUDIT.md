# Current-state audit — 2026-09-26

Historical baseline table below; current result and per-setting inventory are in
`SETTINGS-AUDIT-2026-09-26.md`. FullBlue is now the default and bundled by the installer.

Baseline: `a065e83`, clean working tree before this work. This audit supersedes
old phase status in HANDOFF. “Works” below means implementation exists; it does
not imply hardware or clean-SSD acceptance testing.

| Area | Classification | Evidence / remaining work |
|---|---|---|
| Top panel | Needs bugfix | BarWindow interactive band extended past exclusive zone by Theme.space.xs; shared edge geometry fix underway. |
| Frame | Needs bugfix | FrameReserve already reserves all edges; outer glass still rounded, hole uses independent material radius. |
| Dock | Works, needs polish | DockModel + persisted dock.pinned; DockMenu exists but is not shared with launcher. |
| Launcher | Missing function | Search/placement exist; shared app context menu missing. Preserve placement. |
| Workspace preview | Works, design review only | WorkspaceMap, WindowCapture and Wallpapers already implemented and previously verified. Preserve backends. |
| Control Center | Works, needs polish | AudioDevices and WifiNetworks implemented in latest commit. Brightness slider already exists. |
| Settings | Needs bugfix / incomplete | SettingRow uses fixed editor widths; DisplayPage also has its own unbounded label row. |
| Theme | Works / missing function | Local themes and light/dark/system/auto work; remote catalog/browser absent. |
| IconTheme | Needs change | Central lookup exists; baseline used the former icon default; now replaced by bundled FullBlue. FullBlue exists locally but lacks root LICENSE. |
| Network | Works / missing function | NetworkStatus uses native NetworkManager objects; quick Wi-Fi actions implemented. Full management page absent. VPN also has NM CLI integration in Vpn. |
| Audio | Works | Central PipeWire service, device selection and Bluetooth profile UI already present. No demonstrated need for another Settings page. |
| Media | Works / missing function | MPRIS service and clock/CC presentation exist; topbar widget and explicit player selection absent. |
| Power/Battery | Missing function | Power is powerprofilesctl only. Battery registry entry has no WidgetHost component. |
| Brightness | Works / incomplete | brightnessctl then ddcutil probe, physical writes; single value, no per-monitor discovery or external update tracking. |
| Display | Works / incomplete | Modes, refresh, scale, position and VRR with timed revert. Capability and advanced output coverage need audit. |
| Bluetooth | Works / needs validation | Shared BluetoothDevices backs existing Settings page. Hardware/error testing still needed. |
| Input | Missing function | No full keyboard/mouse/trackpad schema/page. |
| Keybindings | Works / incomplete UI | Central JSON + generator, custom/disabled and workspace style exist. Full conflict/editor audit remains. |
| Language/region | Works / partial | I18n + clock locale/date options; translation completeness tested. Font-scale layout review needed. |
| Advanced/data | Works / organization review | Data, profiles, import/export already exist. Large restructuring requires approval. |
| Installer | Needs hardening | Link/copy installation exists; Nordzy download, SDDM script reference and clean-machine dependencies need review. |
| Migrations/config | Works | Matching JS/Python migrations, version 5, schema validates 232 settings. Preserve custom icon selection. |
| Materials | Works / validation needed | Central ThemeLogic/Python material inheritance and link switch already exist. Preserve per-surface stored values. |

## Acceptance limits

Baseline selftest on Wayland: 381/381; CLI: 21 tests; config validation: OK.
The first sandbox/offscreen attempts could not connect to Wayland, and are not
application regressions. Mesa emits a Zink initialization warning in this test environment.
Actual Vivaldi hover, supported brightness/battery hardware, remote themes and a
clean CachyOS installation on a separate SSD remain acceptance work.

## Design approval boundaries

No large Settings or Workspace Overview redesign is authorized by this audit.
Shared layout bugfixes can proceed. A complete per-setting audit and 2–3 visual
Overview directions must be presented before any larger redesign.

## Result at this handoff

Implemented: edge input band, shared responsive Settings rows, registry cleanup, bundled FullBlue, battery/media widgets, shared app context menu, per-display physical brightness, frame outer/inner geometry, approved preview polish, Network management and Tinted theme browser. See the per-setting audit for missing features and approval proposals.

Final checks: 436 QML selftests, 26 CLI tests, validate OK, installed-copy validate OK. Clean HOME installation and repeat installation succeeded. Doctor required dependencies pass; optional NVIDIA driver probe fails on this host. Doctor's shell-discovery says not running in this tool environment although the production journal confirms successful reloads; do not interpret that as production stopped. Mesa Zink warning persists in selftest. Separate SSD/reboot and interactive hardware acceptance remain unperformed.
