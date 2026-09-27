# Externa API:er som Bifrost förlitar sig på

Syfte: när Hyprland, Quickshell eller Qt uppdateras ska det räcka att gå igenom den här listan
och de filer som nämns. Versionskrav finns i `dependencies.json`; kör `tools/bifrostctl doctor`
och `scripts/selftest.sh` efter varje uppgradering.

Status: ✅ verifierat mot angiven version · ⚠️ antaget/overifierat · 🕓 planerat

## Quickshell 0.3.1 (Qt 6.11)

| API | Används i | Status | Anteckning |
|---|---|---|---|
| `Quickshell.env()`, `shellDir`, `execDetached()`, `reload()` | `Compat/Platform.qml` | ✅ | `shellDir` hette tidigare `shellRoot` |
| `FileView` (`blockLoading`, `waitForJob`, `watchChanges`, `atomicWrites`, `setText`, `loadFailed`) | `Compat/WatchedFile.qml`, `Compat/JsonReader.qml` | ✅ | Att byta `path` laddar inte om synkront — använd `waitForJob()`. Bevakning kräver att katalogen finns när bevakningen startar (WatchedFile skapar den och startar om bevakningen). Skrivning skapar föräldrakataloger. |
| `Process` + `StdioCollector` | `Compat/Exec.qml` | ✅ | `exited` kan komma före `streamFinished` — Exec väntar på alla tre. |
| `IpcHandler` / `qs ipc call` | `Core/CoreIpc.qml` | ✅ | CLI:t delar argument formade som `[a,b]`; skicka JSON-arrayer med inledande mellanslag. `qs ipc -p` hittar bara instanser på **samma Wayland-display**; en nästlad instans nås med `WAYLAND_DISPLAY=<nästlad socket>`. |
| `PersistentProperties` | `shell.qml` | ✅ | Överlever Quickshell-reloads. |
| `Singleton` + `pragma Singleton` (ingen qmldir behövs) | alla singletons | ✅ | |
| `Qt.quit()` / `Qt.exit()` | — | ✅ ej hanterat | Quickshell kopplar inte dessa; selftest skriver en slutrad och avslutas av skriptet. |
| `Quickshell.Hyprland`: `Hyprland.workspaces/monitors/toplevels/focused*/activeToplevel`, `rawEvent`, `refresh*()`, `dispatch()`, `usingLua` | `Compositor/HyprlandBackend.qml` **endast** | ✅ läsning / ⚠️ åtgärder | `dispatch()` skickar strängen rått: i Lua-läge måste den vara Lua (`hl.dsp…`). |
| `Quickshell.processId` + `execDetached(["kill", pid])` | `Compat/Platform.quit()` | ✅ | Självavslut (exit 143). |
| `PanelWindow` + `WlrLayershell.namespace/layer/keyboardFocus`, `ExclusionMode.Ignore` | `shell/gallery.qml` | ✅ | Namespace `bifrost:*` matchar blur-regeln. |
| Modulregistrering för `qs.*` | alla startpunkter | ✅ | Quickshell registrerar bara `qs.*`-moduler som startfilen (transitivt) importerar. Komponenter som skapas med `Qt.createComponent` kan inte använda moduler som inte importerats statiskt — importera dem i startfilen (se `selftest.qml`). |
| `Loader` med `qs:@`-URL / `Qt.createComponent` | `Settings/SettingRow.qml`, selftest | ✅ | Filer i `qs.*`-kataloger som inte finns i startfilens importgraf ger status Error **utan felmeddelande**. Använd statiska `Component`-deklarationer eller importera modulen i startfilen. |
| Typnamn `State` | — | ✅ fallgrop | En egen singleton med namnet `State` skuggas **tyst** av QtQuicks `State`-typ; anrop blir no-ops eller undantag. Därför heter den `Store`. |
| `Qt.fontFamilies()` | `Settings/Editors/FontEditor.qml` | ✅ | |
| `SystemClock` (`precision`, `date`) | `Services/Time.qml` | ✅ | |
| `Quickshell.screens`, `Variants` | `Modules/Bar/Bar.qml` | ✅ | En bar per `screen.name`. |
| `PanelWindow.mask` + `Region { item }` | `Modules/Bar/BarWindow.qml` | ✅ | Bara glaset tar emot input. |
| `PopupWindow` + `anchor.item/rect` | `Components/Popup/BPopup.qml` | ✅ | `PopupWindow` har redan en `closed`-signal; egna signaler får inte heta så. Hyprland-regeln `blur_popups` ger blur. |
| `Quickshell.Services.SystemTray`: `SystemTray.items`, `item.icon/title/tooltipTitle/hasMenu/onlyMenu/menu`, `activate()`, `secondaryActivate()`, `scroll()` | `Services/Tray.qml` (+ `TrayWidget`) | ✅ | Fungerar parallellt med DMS (flera hosts). |
| `QsMenuOpener { menu }` → `children.values` av `QsMenuEntry` (`text`, `icon`, `isSeparator`, `enabled`, `buttonType`, `checkState`, `hasChildren`, signalen `triggered()`) | `Modules/Bar/Widgets/TrayMenu.qml` | ✅ | Menyer ritas som Bifrost-glas; undermenyer öppnas på plats. |
| `FileView` på `/proc/stat`, `/proc/meminfo` | `Services/SystemStats.qml` via `WatchedFile.readFresh()` | ✅ | |
| `DesktopEntries.applications/byId/heuristicLookup`, `DesktopEntry.execute()` | `Services/Apps.qml` | ✅ | Läses in **asynkront** vid start (tom lista de första hundratals ms). |
| `Quickshell.iconPath(name, fallback)` | `Compat/Platform.iconPath` | ✅ | |
| `Pipewire.defaultAudioSink/Source`, `PwNodeAudio.volume/muted`, `PwObjectTracker` | `Services/Audio.qml` | ✅ | Noder måste spåras för att egenskaperna ska vara bundna. |
| `Networking.devices/wifiEnabled`, `DeviceType`, `WifiDevice.networks`, `Network.connected/signalStrength` | `Services/NetworkStatus.qml` | ✅ läsning / ⚠️ Wi-Fi-toggle (ingen Wi-Fi hos användaren) | |
| `Bluetooth.defaultAdapter.enabled/devices` | `Services/BluetoothStatus.qml` | ✅ läsning | |
| BlueZ `org.bluez.AgentManager1.RegisterAgent/RequestDefaultAgent` + eget `org.bluez.Agent1` (KeyboardDisplay) via python-gobject | `tools/bt_agent.py`, `Modules/Bluetooth/PairingAgent.qml` | ✅ protokoll mot falsk BlueZ (`tools/dev/bt_agent_harness.py`), ✅ registrering i production / ⚠️ riktig parning med kodbekräftelse ej provad | Quickshell 0.3.1 registrerar ingen agent. Bara production-shellet kör den (en default-agent per system). `Process.write`/`stdinEnabled` för svaren. |
| `Mpris.players`, `MprisPlayer.*` | `Services/Media.qml` | ✅ | |
| `IpcHandler`-funktionsnamn | `Modules/ModulesIpc.qml` | ✅ | `show` fungerade inte som funktionsnamn (argument avvisades). Använd andra namn. |
| `NotificationServer` (`onNotification`, `trackedNotifications`, `keepOnReload`), `Notification` (`tracked`, `dismiss()`, `closed`, `actions[].invoke()`, `urgency`, `image`, `appIcon`) | `Services/Notify.qml` | ✅ (nested) | `notify-send -i <namn>` levereras som `image` = `image://icon/<namn>`; kortet visar det som appikon. |
| `WlSessionLock { locked }` + `WlSessionLockSurface` | `Modules/Lock/Lock.qml` | ✅ låsning (nested) / ⚠️ upplåsning (kräver användarens lösenord) | |
| `PamContext { config, start(), respond(), responseRequired, onCompleted(PamResult) }` | `Modules/Lock/Lock.qml` | ⚠️ | PAM-tjänst från `lock.pamService` (default `login`). |
| `Quickshell.Services.Polkit`: `PolkitAgent { path, isRegistered, isActive, flow }`, `AuthFlow` (`message`, `identities`, `selectedIdentity`, `inputPrompt`, `responseVisible`, `isResponseRequired`, `supplementaryMessage/IsError`, `failed`, `isCompleted`, `submit()`, `cancelAuthenticationRequest()`) | `Modules/Prompt/PolkitPrompt.qml` | ✅ registrering + `pkexec true` visar prompten och avbryts (production) / ⚠️ lyckad inloggning ej provad av Claude | Bara production (`LazyLoader`), en agent per session; en andra avvisas med "An authentication agent already exists". |
| `Quickshell.Wayland` (session lock), `Services.*`, `Bluetooth`, `Networking`, `DBusMenu`, `Widgets` | fas 4–6 | 🕓 | Moduler kontrolleras av doctor. |

## Qt Quick 6.11

| API | Används i | Status | Anteckning |
|---|---|---|---|
| `ShaderEffect` + `.qsb` (GLSL 440 → qsb 6.11: GLSL 100es/120/150, HLSL 50, MSL 12, SPIR-V) | `Components/Shaders/*`, GlassSurface, StateFill, BIcon | ✅ | Färger skickas som explicita `vector4d` (ej premultiplicerade) för att undvika tvetydighet. `qsb`-formatet är knutet till Qt 6; bygg om med `scripts/build-shaders.sh` vid problem efter Qt-uppgradering. |
| `Qt.alpha(color, a)` | Theme, StateFill, galleri | ✅ | Kräver 0 ≤ a ≤ 1 (annars varning). |
| `Easing.BezierSpline` + `bezierCurve` | `Components/Motion/*` | ✅ | Kurvor från `Theme.motion.curve`. |
| `Qt.labs.folderlistmodel` | `Gallery/IconsSection.qml` | ✅ | Endast galleriet. |

## Hyprland 0.56.2 (Lua-config)

| API | Används i | Status | Anteckning |
|---|---|---|---|
| `hyprctl version -j` → `.version` | `HyprlandBackend`, doctor | ✅ | |
| `hl.define_submap(name, fn)` + `hl.dispatch(hl.dsp.submap(name \| "reset"))` via `hyprctl eval` | `HyprlandBackend.setKeyCapture` (Settings → Shortcuts spelar in) | ✅ nested: definiera, växla, `hyprctl submap`, reset / ⚠️ inspelning med riktiga tangenter ej provad | En omdefinition dubblerar submappens binds → `_G.__bifrost_capture`-vakt (nollställs med Lua-state vid reload). Super+Esc lämnar alltid submappen. |
| `Quickshell.Services.Greetd`: `createSession/respond/launch(cmd, env, quit)/cancelSession`, signaler `authMessage(msg, error, responseRequired, echo)`, `authFailure`, `readyToLaunch`, `error`; `GREETD_SOCK` | `shell/greeter.qml` | ✅ mot `tools/dev/fakegreetd.py` (greetd-IPC: 4 byte längd + JSON) i nested: rätt/fel lösenord, andra fråga, start_session med cmd+env / ⚠️ riktig greetd ej provad | Info-meddelanden besvaras inte (Quickshell kräver bara svar när `responseRequired`). Efter misslyckande skickar Quickshell själv `cancel_session`. |
| Quickshell kraschhanterare | `greeter/session.sh` | ✅ | Vid SIGSEGV avslutas den startade processen (kod 255) och en ny startas fristående → launchern ser "ingen inloggning" och startar reserven. |
| `start-hyprland -- …` (Hyprland 0.56) | `greeter/bin/bifrost-greeter` | ✅ nested | Utan den visar Hyprland en varningsbanner. |
| `IdleMonitor { timeout, respectInhibitors, isIdle }` (Quickshell.Wayland, ext-idle-notify-v1) | `Modules/Idle/Idle.qml` | ✅ nested: släck efter 1 min, väck med pekare, lås efter 1 min, ändrad tid under körning | Behåller timeouten den skapades med → ny monitor per inställningsvärde (`Variants`). |
| `hl.dsp.dpms({ action = "on"\|"off" })`, `misc.key_press_enables_dpms/mouse_move_enables_dpms` | `HyprlandBackend.setDisplaysPower`, generatorn | ✅ nested (`dpmsStatus`), verify ok | Väckningen i Hyprland gör att skärmen tänds även utan shell. |
| `hyprctl eval '<lua>'` | `HyprlandBackend.applySurfaceEffects` | ✅ | Runtime-only, fält valideras för `hl.layer_rule` (okända fält → fel). Lua-globaler består mellan eval-anrop. |
| `hl.layer_rule({ match = { namespace = … }, blur, ignore_alpha, blur_popups })` | samma | ✅ | Återappliceras (tvingat) efter `configreloaded`. |
| `hyprctl dispatch X` = `hl.dispatch(X)` i Lua-läge | — | ✅ | Klassisk syntax (`workspace 3`) fungerar **inte** längre med Lua-config. |
| `hl.dsp.focus({ workspace = "N" })` | `focusWorkspace` | ✅ | Används i användarens egna binds. |
| `hl.dsp.window.move({ workspace = "N", window = "address:0x…" })` | `moveWindowToWorkspace` | ✅ (nested, fas 6) | Fokus **följer med** till mål-workspacen (inte "silent"). |
| `hl.dsp.window.close({ window })`, `hl.dsp.window.fullscreen({ mode, action, window })`, `hl.dsp.window.float({ action, window })`, `hl.dsp.focus({ window })` | resp. åtgärd | ✅ (nested, fas 6) | Verifierat via Bifrosts `wm`-IPC mot `hyprctl clients` i nested-läge. Dispatcher-konstruktorer validerar inte fältnamn, så bara körning bevisar formen. |
| Minimera: `hl.dsp.window.move({ workspace = "special:bifrost-minimized", follow = false, window })`, `hl.dsp.window.pin({ action = "set"\|"unset", window })`, `hl.get_active_window()`, `hl.get_workspace_windows(sel)`, allt i **ett** `hyprctl eval` | `HyprlandBackend.minimizeWindow/restoreWindow` | ✅ nested 0.56.2 | Hyprland har inget eget minimize. Tyst flytt till special-workspacet flyttar inte fokus från *andra* fönster, men ett fokuserat sista fönster behåller tangentbordet (fångas upp i samma eval: annat fönster, eller hopp via `name:bifrost-refocus` och tillbaka). Pinnade fönster går inte att flytta förrän pin tagits bort. Fullscreen/maximerat följer med fönstret. Tomma workspaces försvinner → återskapas på fönstrets skärm vid återställning. `hyprctl eval` skriver ingen utdata (fel märks bara via exit/stderr). |
| `hl.dsp.exit()` | `exitSession` | ✅ form (samma mönster) | Körs bara i nested/production via `Session.logout()`. |
| `Hyprland --verify-config --config <wrapper.lua>` (wrapper `dofile`:ar den genererade filen) | `bifrostctl hypr verify/generate` | ✅ | Fångar okända fält och syntaxfel; skriver "config ok" vid framgång. |
| `Hyprland --config <lua>` nästlat, `hyprctl output create headless` | `scripts/nested.sh` | ✅ | Headless-utgången fick upplösning 0×0 när den sattes via `hl.monitor`; används inte. Utan `start-hyprland` visar Hyprland en varningsrad (ofarligt i testinstansen). |
| Event-socket: `workspacev2`, `focusedmonv2`, `activewindowv2`, `openwindow`, `closewindow`, `movewindowv2`, `changefloatingmode`, `fullscreen`, `windowtitlev2`, `create/destroyworkspacev2`, `monitoradded/removedv2`, `configreloaded` | `HyprlandBackend.eventMap` | ⚠️ | Namn från Hyprlands IPC-dokumentation; endast `configreloaded`-hanteringen är central. |
| Env `HYPRLAND_INSTANCE_SIGNATURE` | `Compositor`, `HyprlandBackend` | ✅ | |
| `Hyprland.monitors` / `workspaces` egenskaper efter `refresh*()` | `HyprlandBackend.refresh` | ✅ | Fylls i **asynkront**: första läsningen ger bredd 0 och ingen aktiv workspace. Backenden normaliserar två gånger (direkt och efter 250 ms) med `lastIpcObject` som reserv. |
| `HyprlandFocusGrab { windows, active, onCleared }` | `HyprlandBackend.createFocusGrab` | ✅ | Stänger popups vid klick utanför. |

## Niri (planerat)

| API | Används i | Status |
|---|---|---|
| Env `NIRI_SOCKET` | `Compositor` (detektering) | ✅ |
| `niri msg --json …`, event-stream | `NiriBackend.qml` | 🕓 |

## System

| API | Används i | Status |
|---|---|---|
| `fc-list : family` | doctor | ✅ |
| `qtpaths --qt-version`, `--query QT_INSTALL_QML` | doctor | ✅ |
| `mkdir -p` | `WatchedFile` | ✅ |
| `$XDG_RUNTIME_DIR` | `Paths.runtimeDir` (applied.json) | ✅ |
| `nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits` | `Services/GpuStats.qml` | ✅ (driver 615) |
| `kill -0 <pid>` | `ApplyState.checkAlive` | ✅ |
| `systemctl --user is-active dms.service`, `systemd-analyze --user verify` | `doctor --production`, (manuell kontroll av enheten) | ✅ |
| `piactl get connectionstate|region`, `piactl connect|disconnect` | `Services/Vpn.qml` | ✅ läsning (3.7.2) |
| `nmcli -t -f NAME,TYPE,STATE connection show`, `nmcli connection up|down id` | `Services/Vpn.qml` | ⚠️ (inga NM-VPN hos användaren) |
| `powerprofilesctl get|set|list` | `Services/Power.qml` | ✅ läsning (0.30) |
| `brightnessctl -m -c backlight info|set` | `Services/Brightness.qml` | ⚠️ (ingen backlight hos användaren) |
| `ddcutil getvcp 10 --brief`, `setvcp 10` | `Services/Brightness.qml` | ⚠️ (ingen DDC/CI-skärm hittad hos användaren) |
| DMS-filer: `~/.config/DankMaterialShell/settings.json` (`barConfigs[0]`, `dockIconSize`, `showDock`, `showWeekNumber`, `iconThemeDark`, `cornerRadius`), `~/.local/state/DankMaterialShell/session.json` (`wallpaperPath`, `pinnedApps`, `hiddenApps`, `weatherLocation`), `themes/*/theme.json` | `tools/bifrostctl import-dms` | ✅ read-only (DMS 1.6.1, configVersion 18) | Formatet kan ändras med DMS-versioner; importen tål saknade fält. |
| Qt locale (`Qt.locale(name).toString(date, fmt)`) | `Services/Time.qml` | ✅ | Systemet är `en_GB`; `clock.locale` väljer språk. |

## Nätverk

| API | Används i | Status | Anmärkning |
|---|---|---|---|
| Open-Meteo `GET https://api.open-meteo.com/v1/forecast?latitude&longitude&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m&daily=temperature_2m_max,temperature_2m_min,weather_code&forecast_days=4&timezone=auto[&temperature_unit=fahrenheit]` | `Services/Weather.qml` (XMLHttpRequest) | ✅ 2026-09-25 | Ingen nyckel. Koordinater avrundas till 2 decimaler. WMO-väderkoder. Hämtas bara när klockmenyn är öppen. Av med `clock.menu.weather`. |
| MPRIS `position`/`length` (`positionSupported`, `lengthSupported`; `positionChanged()` måste emitteras för att läsa om) | `Services/Media.qml` | ⚠️ | Quickshell 0.3.1-källan kontrollerad; ingen spelare aktiv vid test. |


## Continuation 2026-09-26
- FullBlue: bundled editable SVG snapshot, upstream GPL-3.0 and attribution from
  https://github.com/SylEleuth/gruvbox-plus-icon-pack at 4871affc1679ed91f541061afb2e5e96a1027fe4.
- UPower: Quickshell 0.3.1 installed qmltypes checked for displayDevice.ready,
  isLaptopBattery/isPresent, percentage (0–1), state, timeToEmpty/timeToFull and
  UPower.onBattery. Native properties supply live updates; no polling.
  https://quickshell.org/docs/v0.3.0/types/Quickshell.Services.UPower/UPowerDevice/

### Network profile management
NetworkManager nmcli: connection show/up/down/modify/delete, device status/show/connect/disconnect and wifi rescan. One monitor refreshes shared state. Optional python-gobject calls system-bus org.freedesktop.NetworkManager GetDeviceByIpIface and AddAndActivateConnection for hidden open/WPA-personal Wi-Fi. Enterprise creation delegates to nm-connection-editor when installed. Profile changes require reconnect; errors are exposed in Settings. API: https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.html

### Weather location search
WeatherLocationEditor calls https://geocoding-api.open-meteo.com/v1/search with an explicitly submitted city/postcode, count=8 and language=en. It presents name/admin1/country choices, persists only the chosen name/lat/lon/zone through Config, and aborts timed-out or replaced requests. Location data attribution: Open-Meteo / GeoNames. Documentation verified: https://open-meteo.com/en/docs/geocoding-api . Forecasts continue through the existing Weather service.

### Input settings (2026-09-26)
Hyprland 0.56.2 `hl.device` fields and `hl.gesture` registration/removal checked against installed headers and upstream tagged source (`src/config/lua/bindings/LuaBindingsConfigRules.cpp`, `TrackpadGestures.cpp`). Per-device configuration emits only user-edited fields via the existing bifrost.lua generator; the previous values are restored when overrides are removed. `hyprctl devices -j`, batched `getoption`, and `switchxkblayout` provide discovery/defaults/active layout. Gesture mappings are global in this backend. Literal existing gestures are discovered read-only from main Lua config and its require graph; opaque callbacks are labelled custom, never evaluated by discovery. Removing an override for an opaque custom callback cannot reconstruct it until the compositor reloads its original config; no reload is issued automatically.
Hardware capability detection prefers the libinput C API without event dispatch/grabs. Where event nodes are inaccessible, conservative kernel capability bitmaps plus udev classification enable documented standard mouse/full-multitouch features; uncertain controls remain hidden. External trackpads do not receive an inferred DWT control. Palm detection is automatic in libinput with no exposed Hyprland toggle. XKB layouts, variants and modifier options use installed evdev.xml.
Sources: https://wiki.hypr.land/configuring/core/devices/ ; https://wiki.hypr.land/configuring/core/binds/keyboard-layouts/ ; https://wayland.freedesktop.org/libinput/doc/latest/configuration.html ; https://wayland.freedesktop.org/libinput/doc/latest/tapping.html .

## Window overview and native workspace motion (2026-09-26)
- Quickshell 0.3.1 `ScreencopyView` via existing Compat/WindowCapture and Compositor.captureSource supplies live toplevel previews. Source: https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/ScreencopyView/ . `hasContent` gates the app-art fallback; capture is live only while visible/open. Hidden apps may stop producing fresh frames.
- Hyprland 0.56.2 native horizontal `workspace` gesture owns continuous displacement, reversal, cancellation and speed-based completion. Existing cancel_ratio=0.5 and min_speed_to_force=30 verified read-only; retained. No QML gesture emulation or direct /dev/input reader. https://wiki.hypr.land/configuring/core/binds/gestures/ and https://wiki.hypr.land/configuring/core/config-options/ .
- `hl.curve` and `hl.animation` were checked against v0.56.2 LuaBindingsConfigRules.cpp and generated config verification. workspaces/workspacesIn/workspacesOut use slide with ease-in-out; child fade settings cannot supersede it. Other animation leaves untouched. https://wiki.hypr.land/configuring/core/animations/ .
- Silent drag-to-workspace uses `hl.dsp.window.move({workspace=...,window=...,follow=false})`, verified in v0.56.2 LuaBindingsDispatchers.cpp. Legacy backend already uses movetoworkspacesilent. Actual host window dispatches were not injected for testing.
- Limits versus macOS: compositor workspaces are per-output, wallpaper/layer-shell panels remain fixed; no whole-desktop wallpaper slide. Pinch invokes open/close callbacks, not a finger-driven overview zoom. Native swipe supports the requested continuous workspace transition. No compositor plugin or DMS runtime dependency.

### mpv MPRIS integration (2026-09-26)
The current local mpv lacked MPRIS. Upstream https://github.com/hoyon/mpv-mpris at de552ae185399073b4fbc8557fa64c9543cdcf9f was built against installed mpv/glib/gio/libavformat, tested on isolated D-Bus (metadata and pause), and installed as the user's mpv script plugin. mpv auto-loads it on its next start; the shell continues to use its existing Quickshell MPRIS service. No alternate media backend was added.

Global material shadow maps to `decoration.shadow.enabled/range` through generated Lua (under hyprland.manage). Verified 2026-09-26 against https://wiki.hypr.land/Configuring/Basics/Variables/#shadow and running Hyprland 0.56.2. Application-rendered shadows are outside this control.

XWayland unnamed floating menu blur workaround: `hl.window_rule` match `class/title = "^$"`, `xwayland/float = true`, `no_blur = true`. Syntax verified against https://wiki.hypr.land/configuring/core/rules/window-rules/ and live Hyprland 0.56.2. Screenshot verified removal of ChatGPT menu's blurred transparent surround.

VRR workaround verified against Hyprland v0.56.2 source: src/config/shared/monitor/MonitorRule.cpp (VRR absent from comparison), src/config/supplementary/propRefresher/PropRefresher.cpp (VRR refresh before scheduled monitor update), src/config/lua/bindings/LuaBindingsToplevel.cpp (hl.timer oneshot), src/output/Monitor.cpp (1Hz mode match tolerance). Sources: https://github.com/hyprwm/Hyprland/tree/v0.56.2/src . Live DP-2 on/off state and unchanged physical mode verified.
