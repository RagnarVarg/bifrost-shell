# Bifrost Shell — arkitektur

Status och nästa steg: se `docs/HANDOFF.md`. Nuvarande production-setup: `docs/INVENTORY.md`.
Externa API:er Bifrost förlitar sig på: `docs/EXTERNAL-APIS.md`.

## 1. Principer

1. **Production (DMS + nuvarande Hyprland-config) rörs aldrig.** Bifrost skriver bara i repot,
   `~/.config/bifrost/` och `$XDG_RUNTIME_DIR/bifrost/`. Aldrig `~/.config/hypr/`,
   `~/.config/DankMaterialShell/`, systemd-units eller systemfiler.
2. **En sanningskälla per sak**: schema → inställningar, `themes/_base.json` → design tokens,
   `dependencies.json` → beroenden/versioner.
3. **Settings är förstaklassig**: samma Core som shellet, egen process, UI genererat från schemat.
4. **Inget beroende av DMS.** DMS får vara referens och engångs-importkälla (översätts till Bifrost-format).
5. **Versionskänslig kod bor på få ställen**: `shell/Compat/` (Quickshell) och
   `shell/Compositor/*Backend.qml` (compositorn). Resten av koden ser aldrig `hyprctl`, Lua-config,
   Niri-IPC eller Quickshells låg-nivå-API:er.

## 2. Lager

```
 Modules/ (bar, dock, launcher …)      Settings/ (appen)
            │                               │
            └──────────┬────────────────────┘
                 Components/ (GlassSurface, StateLayer, Controls, Icons, Text, Motion)
                       │
                     Core/  Config · Schema · Theme · ApplyState · Paths · RunMode · CoreIpc
                       │
                 Compositor/  Compositor (fasad) → HyprlandBackend | NiriBackend | CompositorBackend
                       │
                    Compat/  Platform · Exec · WatchedFile · JsonReader · Deps · Version.js
                       │
            Quickshell / Qt / compositor-IPC / filsystem
```

Regel: ett lager importerar bara lager under sig. UI-moduler importerar `qs.Core`, `qs.Components`
och `qs.Compositor` (fasaden), aldrig `Quickshell.Hyprland` eller backends direkt.

## 3. Repo-struktur

```
bifrost-shell/
├── CLAUDE.md                 regler + läsordning för nya Claude-sessioner
├── dependencies.json         ALLA externa beroenden, minimiversioner, versionsstyrda features
├── shell/                    Quickshell-rot (imports: qs.Compat, qs.Compositor, qs.Core …)
│   ├── shell.qml             shellet            →  qs -p shell/          (scripts/dev.sh)
│   ├── settings.qml          Settings-appen     →  scripts/settings.sh [sektion|nyckel]
│   ├── selftest.qml          selftest           →  scripts/selftest.sh
│   ├── gallery.qml           komponentgalleri   →  scripts/gallery.sh
│   ├── Gallery/              galleriets sektioner (bara för galleriet)
│   ├── Compat/               Quickshell-isolering + versionshjälp
│   ├── Compositor/           compositor-abstraktion + backends
│   ├── Core/                 config, schema, tema/tokens, apply-state, IPC
│   ├── Components/           delade UI-komponenter: Glass/ State/ Controls/ Text/ Icons/ Motion/ Shaders/
│   ├── Modules/              bar, dock, launcher, notiser, CC, tray, lock … (fas 4–6)
│   └── Settings/             Settings-appen: SettingsApp, Sidebar, SectionPage, SettingRow, Editors/
├── schema/                   index.json + en fil per sektion
├── themes/                   _base.json (tokens) + teman
├── presets/                  inbyggda presets (partiella configs)
├── tools/bifrostctl          CLI: get/set/reset/list/show/validate/doctor (+ tester)
├── scripts/                  dev.sh, selftest.sh (nested.sh i fas 6)
└── docs/
```

## 4. Körlägen (`BIFROST_RUN_MODE`, `Core/RunMode.qml`)

| Resurs | `overlay` (default, bredvid DMS) | `nested` | `production` |
|---|---|---|---|
| Bar/dock/launcher/CC/Settings | ✅ utan reserverat skärmutrymme | ✅ | ✅ |
| Notification-server, polkit, session lock, wallpaper | ❌ (DMS äger dem) | ✅ | ✅ |
| Hyprland-utseende (`hyprland.*`) | ❌ | ❌ | ✅ om `hyprland.manage` |
| Surface blur för `bifrost:*` | ✅ runtime-regel | ✅ | ✅ |

`scripts/dev.sh` vägrar `production` så länge `dms.service` är aktiv.

## 5. Konfigurationssystemet

### 5.1 Schema (`schema/*.json`)
Varje inställning deklareras en gång:
```json
{ "key": "bar.height", "type": "int", "default": 38, "min": 24, "max": 72, "unit": "px",
  "label": "Höjd", "description": "…", "group": "layout",
  "scope": "shell",            // shell | hyprland | system
  "apply": "live",             // live | reload | restart
  "nullable": false,           // null = ärv (oftast från temat)
  "advanced": false,
  "dependsOn": "bar.enabled",  // UI: visa/aktivera bara om den är sann
  "requires": { "compositor": ["hyprland"], "capability": "surfaceBlur" },
  "editor": "WidgetLayoutEditor" }   // valfri specialeditor
```
Typer: `bool int real enum color string font icon path list object widgetLayout`.
`requires` kan också sättas på sektionsnivå. `Schema.isSupported(key)` avgör om Settings visar posten.
Schemat valideras vid laddning (dubbletter, överlapp, default inom gränser); `Schema.search()` ger settings-sök.

### 5.2 Lager och fil
`values = schema-defaults ⊕ preset ⊕ användar-overrides`

`~/.config/bifrost/config.json` är **sparse**:
```json
{ "version": 1, "preset": "compact", "values": { "bar": { "height": 44 } } }
```
- Sätta ett värde lika med basen (default ⊕ preset) tar bort nyckeln → reset = ta bort nyckeln.
- Okända nycklar behålls i filen (rapporteras som issues), ogiltiga värden ignoreras men behålls.
- Ogiltig JSON eller nyare `version` → Config vägrar skriva (skyddar handredigerade filer).
- Äldre `version` → `Core/Migrations.js`, originalet sparas i `backups/`.
- Båda processerna bevakar filen; den är enda kanalen för bestående ändringar. Skrivning debounce 80 ms, atomiskt.
- `BIFROST_PRESET` lägger på en preset temporärt; `BIFROST_CONFIG_DIR` används bara av tester.

### 5.3 Presets vs profiler
- **Preset** = partiellt baslager (`presets/*.json`, `~/.config/bifrost/presets/*.json`), väljs med `preset`.
- **Profil** (fas 7) = sparad ögonblicksbild av användarens overrides (`~/.config/bifrost/profiles/`), kan växlas/exporteras.

### 5.4 Apply-lägen
`live` slår igenom direkt. `reload`/`restart`: shellet publicerar vad det applicerat till
`$XDG_RUNTIME_DIR/bifrost/applied.json` (restart-värden sparas över Quickshell-reloads via
`PersistentProperties`). `ApplyState.pendingReload/pendingRestart` används av Settings för tydliga banners.

### 5.5 Presets, profiler, import/export, DMS-import (fas 7)
**Alla dataoperationer finns bara i `tools/bifrostctl`.** Settings anropar CLI:t via `Core/Ctl.qml` och `--json`.
- Presets: `presets/*.json` (Kompakt, Luftig, Minimal) och `~/.config/bifrost/presets/`. Byte behåller användarens
  ändringar.
- Profiler: `~/.config/bifrost/profiles/<namn>.json` = `{ name, created, preset, values }`. Att ladda en profil ersätter
  overrides (backup först).
- Paket: `.bifrost.json` = `{ format: "bifrost-bundle", version, created, preset, values, themes }`.
  Export till `~/.config/bifrost/exports/`. Import visar diff först, och `--apply` tar backup och skriver.
- DMS-import: `bifrostctl import-dms [--apply] [--appearance] [--themes]` läser `settings.json`, `session.json` och
  teman **read-only**.
  - Översätter wallpaper, fästa och dolda appar, dock, veckonummer, ikontema, bar-autohide och bar-widgets
    (se `DMS_WIDGETS`).
  - Utseende bara med `--appearance`. DMS-teman konverteras till `~/.config/bifrost/themes/dms-*.json`.
  - Det som saknar motsvarighet rapporteras. DMS läses aldrig i drift.
- Runtime-state (inte inställningar): `~/.config/bifrost/state.json` via `Core/Store.qml`.
  Heter `Store` eftersom `State` krockar med QtQuicks typ.

## 6. Design tokens, material och Bifrost-prisma

`themes/_base.json` definierar allt strukturellt: `space`, `radius`, `border`, `opacity`, `elevation`,
`motion` (durations + easing), `font`, `color` (semantiska roller), `glass`, `materials`, `prism`, `states`.
Ett tema (`extends: "_base"`) ger `variants.dark` / `variants.light` (palett + ev. overrides).

- Färger i paletten är opaka `#RRGGBB`; transparens uttrycks `{ "color": "@palette.x", "alpha": "@opacity.y" }`
  och löses centralt till Qt:s `#AARRGGBB`.
- `@a.b` refererar andra tokens.
- `Core/Theme.qml` + `ThemeLogic.js` applicerar appearance-inställningar centralt: accent, radie-/spacing-skala,
  glas (tjocklek/korn/kantljus/blur), kantstyrka, skuggor, prisma, animationshastighet, typsnitt/skala, variant.
- **Material** (`Theme.materials.bar|dock|panel|popover|osd|tooltip|lock`): alla ytor använder
  `Components/Glass/GlassSurface.qml` med ett material → ett glassystem. Shadern `glass-frame.frag` ritar
  skugga, ton, djup (mörkare nedåt), toppljus, diagonal reflex, korn, inre kant (ljusare upptill) och yttre hårlinje.
- **States** (`Theme.states.hover|pressed|selected|active|focus`): `fill` = `solid | prism | ring` + intensitet.
  `Components/State/StateLayer.qml` (via `StateFill`) ritar dem; kontroller sätter bara booleans.
  Prismat (`prism.frag`): fyllningen lutar mot tre dämpade aurora-färger, en svag ljusdelning under överkanten
  och en kant som skiftar nyans runt om. Parametrar i `Theme.prism` (tint, caustic, edge, dispersion, driftSeconds).
  Prisma av → faller till `solid`.
- **Typografi**: roller i `Theme.typography` (display, title, heading, body, label, caption, overline, mono, readout)
  via `BText { role; tone }`. Geist för UI, Geist Mono för teknisk information.
- **Kontroller** (`Components/Controls/B*.qml`) och ikoner (`BIcon`, `assets/icons/*.svg`, vita linjer som färgas
  med `tint.frag`) läser bara tokens. Animationer via `BNumberAnimation`/`BColorAnimation` (motion-tokens).
- Shaders ligger i `Components/Shaders/*.frag`; kompilerade `.qsb` committas (`scripts/build-shaders.sh`).

### Glas
Bakgrundsoskärpa kan bara compositorn göra. Shellet ber compositor-fasaden:
`Compositor.ensureSurfaceEffects("bifrost:", { blur: true })`. Hyprland-backenden lägger en
**runtime-only** layer rule (`hyprctl eval`, idempotent via en Lua-global, återappliceras efter config-reload).
Resten av looken (ton, toppkant-highlight, inre/yttre kant, korn, skugga) görs i QML från materialet.

## 7. Compositor-abstraktion

`Compositor` (singleton, fasad) väljer backend via `HYPRLAND_INSTANCE_SIGNATURE` / `NIRI_SOCKET`
(`BIFROST_COMPOSITOR` tvingar). Gemensam datamodell (vanliga JS-objekt):

```
workspace { id, name, index, monitor, active, focused, urgent, windowCount, special }
window    { id, appId, title, workspaceId, workspaceName, monitor, focused, floating, fullscreen,
            minimized, minimizedAt }
monitor   { name, x, y, width, height, scale, refreshRate, focused, activeWorkspaceId }
```
Åtgärder: `focusWorkspace, focusWindow, moveWindowToWorkspace, closeWindow, setFullscreen, setFloating,
minimizeWindow, restoreWindow, ensureSurfaceEffects`. Händelser: `event(name, data)` med normaliserade namn (`workspace`, `focus`,
`window-opened`, `window-closed`, `window-moved`, `window-changed`, `monitors`, `config-reloaded`).
**Capabilities** (`Compositor.supports("floating")` …) används av UI och av schemats `requires` — aldrig compositornamn.

- `HyprlandBackend.qml`: enda filen med `Quickshell.Hyprland`, dispatch-syntax och `hyprctl`.
  Väljer Lua- eller legacy-dispatch via `Hyprland.usingLua`.
- `NiriBackend.qml`: stub (detekteras, alla capabilities false). Implementeras via `niri msg --json` + event-stream.
- `CompositorBackend.qml`: kontraktet + no-op-standarder (används också när ingen compositor känns igen).
- **Minimera** (capabilities `minimizeWindow`, `restoreWindow`, `minimizedWindowState`): backenden döljer
  fönstret och rapporterar `minimized` ur compositorns state (aldrig ur geometri). Allt compositor-neutralt
  – var fönstret ska tillbaka, städning av stängda, Dockans val, Overviews filter – ligger i
  `Compositor/Minimize.js` (testat i selftest). Fasaden: `focusWindow` och `moveWindowToWorkspace` på ett
  minimerat fönster återställer det; `activateAppWindows` är Dockans klick. Hyprland: Bifrost-ägt
  `special:bifrost-minimized`, återställningsinfo i `$XDG_RUNTIME_DIR/bifrost/minimized-<instans>.json`.
  En Niri-backend behöver bara implementera `minimizeWindow/restoreWindow` och sätta `minimized`.

Hyprland-inställningar (`schema/hyprland.json`, `requires.compositor = ["hyprland"]`) ligger under
Avancerat, skrivs i fas 8 bara till `~/.config/bifrost/hypr/bifrost.lua` och appliceras bara i production.

## 8. Beroenden och hälsa

- `dependencies.json`: id, nivå (required/recommended/optional), `min`, `tested`, check-metod, install-kommando,
  versionsstyrda features (t.ex. `hyprland.features.hyprctlEval`).
- `Compat/Deps.qml` läser den i QML; backends gate:ar features med `Version.js`.
- `tools/bifrostctl doctor` kontrollerar allt i manifestet + session + schema + config.

## 9. IPC

`qs ipc -p <repo>/shell call bifrost <fn>`: `ping`, `status`, `get KEY`, `set KEY JSON`, `reset KEY`,
`token PATH`, `reload`. Obs: `qs ipc`-CLI:t delar argument formade som `[a,b]` — skicka JSON-arrayer med
inledande mellanslag (`' ["a"]'`). `bifrostctl` har inte det problemet.

## 10. Bifrost Settings

- Egen process: `scripts/settings.sh [sektion|inställningsnyckel]`, `qs ipc … call bifrost openSettings <sida>` från
  shellet, eller IPC-target `settings` (`open`, `search`, `close`) i en körande instans.
- **Presentation: ett centrerat Bifrost-glaslager** (`bifrost:settings`), inte ett vanligt fönster. Ett vanligt
  fönster skulle få kanter, radie och färger från användarens Hyprland/DMS-config och kräva fönsterregler.
  Lagret använder samma glas och blur-regel som resten av Bifrost. Nackdel: det kan inte flyttas eller alt-tabbas.
  Det kan omprövas i production-läge.
- **Allt genereras från schemat.** Sidomenyn byggs från kategorier, deras sektioner som stöds av compositorn och
  kategoriernas egna `pages` (t.ex. `DataPage`). En sektion visar sina grupper (`groups`-etiketter) som
  grupperade listor. `SettingRow` väljer editor från `editor` eller `type`:

  | typ | editor |
  |---|---|
  | bool | BoolEditor (toggle) |
  | int / real | NumberEditor (slider + värde; `nullable` → chip "Tema", visar ärvd token via `inherit`) |
  | enum | SegmentedEditor (≤ 3 val) / EnumEditor (dropdown); etiketter från `optionLabels` |
  | color | ColorEditor (hex, färgruta, snabbval ur paletten) |
  | font | FontEditor (installerade typsnitt, sökbar) |
  | icon | IconThemeEditor |
  | list | ListEditor, eller `ScreenListEditor` |
  | widgetLayout | WidgetLayoutEditor (vänster/mitten/höger, register i `schema/widgets.json`) |
  | string | TextEditor, eller `ThemeEditor` |

- Per rad: markör för ändrat värde, återställning, not om `apply` (reload/restart) och om ändringen väntar.
  `dependsOn` inaktiverar raden.
- Per sektion: "Återställ sektion". På datasidan: "Återställ alla" med bekräftelse.
- Globala banners: ogiltig `config.json`, ändringar som väntar på reload (med knapp som laddar om shellet via IPC)
  eller restart. Sektioner med `requires.compositor` visar compositor, version och att värdena bara appliceras
  i production-läge.
- Sök (`Schema.search`) med hopp till sektionen och markering av raden.
- Nya editorer måste registreras statiskt i `SettingRow.editors`. Quickshell kan inte ladda `qs:@`-URL:er till
  filer utanför importgrafen; Loadern får då status Error utan felmeddelande.

## 10b. Top bar och tjänster (fas 4)

- `Modules/Bar/Bar.qml` skapar ett `BarWindow` per skärm i `bar.screens`.
  - Stilar: `floating` (marginal och radie), `attached` (kant i kant, rak) och `islands` (ett glas per zon).
  - Placering uppe eller nere. Input-mask bara på glaset. Exklusiv zon bara när `RunMode.reservesScreenSpace`.
  - Autohide: kantremsa visar baren, fördröjning, baren hålls synlig medan popups är öppna.
  - Scrollhjulet byter workspace via `Compositor.focusRelativeWorkspace`.
- Widgets (`Modules/Bar/Widgets/`) ärver `BarWidget` (`entry`, `bar`, `shown`) och deklareras statiskt i `WidgetHost`.
  Registret i `schema/widgets.json` är kontraktet; `since` markerar senare faser.
  Widgets anger `shown`, aldrig `visible`, eftersom effektiv synlighet annars loopar via värden.
- Tjänster (`shell/Services/`): `Time`, `SystemStats` och `GpuStats` pollar bara medan någon `retain()`:at dem.
  `Tray` omsluter Quickshells SystemTray. Widgets använder bara tjänsterna, aldrig Quickshell-moduler eller verktyg direkt.
- Popups: `Components/Popup/BPopup.qml` (glas och `Compositor.createFocusGrab`). Används av docken och dropdowns.
- Barmenyer (status, skärm, tray, systemstatus och systemmenyn) är **inte** popups. De ärver `Modules/Bar/BarMenu.qml`
  och ritas i barens eget fönster av `Modules/Bar/MenuHost.qml`, som en förlängning av glaset de öppnas från:
  - `GlassSurface.attachment` lägger en rektangel (`ext`), en brygga över skarven och konkava hörn (`fillets`) till
    glaskroppen. Shadern ritar allt som en SDF-form, med samma kant, material och skugga.
  - Menyn centreras under ankaret inom sitt glas och läggs jäms med glasets kant när ett konkavt hörn inte får plats.
    Är menyn bredare än en ö hänger den ut ("svamp") med konkava hörn uppåt mot ön. Med baren nere speglas formen.
  - Barfönstret växer direkt när en meny öppnas och krymper när stängningsanimationen är klar.
  - Stängning: pekaren lämnar menyn och ankaret i `bar.menus.closeDelayMs` (efter att den varit inne), Esc,
    en annan meny öppnas (`PopupGroup`), eller ett klick utanför via focus grab. Greppet hålls bara när hover-stängning
    inte kan ta hand om det (avstängd, eller innan pekaren varit inne), eftersom Hyprland inte skickar leave medan
    greppet finns. Innan stängning frågas compositorn var pekaren är (`Compositor.pointerInAny`).
  - Öppning vid hover: `Modules/Bar/HoverIntent.qml` (`bar.menus.openOnHover`, `hoverDelayMs`), stängning:
    `Modules/Bar/LeaveWatch.qml` (`closeOnLeave`, `closeDelayMs`, kontroll via compositorn). Båda delas av `BarMenu`/`MenuHost`
    och control center (som är en egen panel men öppnas och stängs som en barmeny när den öppnas från baren).
    `BarMenu.click()` från ankaret: ett klick på en meny som hover precis öppnade behåller den öppen. Traymenyer öppnas
    inte vid hover (`openOnHover: false`), och systemstatus öppnas alltid vid hover. Alla menyer registreras i `PopupGroup`.
  - `bar.menus.contentTopPadding` ger extra luft överst i alla barmenyer (`BarMenu.topPadding`).
  - Ankare exponerar `hovered` (BarButton, status- och tray-ikoner, systemstatusytan). Deras egen MouseArea är den
    enda pålitliga hover-källan. En HoverHandler ovanpå får inget leave när pekaren går vidare till en widget.
  - Ny meny: `BarMenu { bar: widget.bar; anchorItem: button }` och `selected: menu.isOpen` på knappen.
- Systemmenyn (`Widgets/SystemMenu.qml`, power-knappen längst till vänster) är byggd som macOS Apple-meny: Om Bifrost
  (`Services/SystemInfo`), Systeminställningar, Programvara (`power.softwareApp` eller hittad), Senaste objekt
  (`Services/RecentFiles`, freedesktops `recently-used.xbel`, bara läsning), Tvångsavsluta (`kill -KILL` per pid, inte
  i overlay-läge), Vänteläge/Starta om/Stäng av, Lås/Logga ut via `Session`. IPC `bar statusMenu system[:about|recent|forceQuit]`.
  Den helskärmsbaserade power-menyn finns kvar för IPC `power toggle`.

## 10c. Launcher, control center, dock, OSD (fas 5)

- `Modules/ShellState.qml`: transient UI-state (vilken panel är öppen på vilken skärm, OSD). Launcher och control center
  utesluter varandra. `Modules/ModulesIpc.qml` ger IPC-targets `launcher`, `controlcenter`, `audio`, `brightness`,
  `osd`, som kan knytas till tangenter när Bifrost blir det riktiga shellet.
- **Launcher** (`Modules/Launcher/`): helskärmslager (klick utanför stänger), centrerat panelglas, sökfält och
  app-grid, tangentbordsnavigering.
  - **Providers** har kontraktet `id, label, search(query) → [{ key, title, subtitle, icon, score, run() }]`.
    `AppsProvider` finns; senaste appar, kommandon och systemåtgärder läggs till som egna providers utan UI-ändring.
- **Control center** (`Modules/ControlCenter/`):
  - panelglas under barens högra ände; stängs vid klick utanför (focus grab) eller Esc
  - rutor (`CCTile`) och reglage (`CCSlider`); rutor för funktioner som saknas döljs (VPN, ljusstyrka, energiprofil)
- **Dock** (`Modules/Dock/`):
  - `DockModel.js` bygger poster från `dock.pinned` och `Compositor.windows`: fästa först, sedan körande
  - markeringar: körande = punkter, aktiv = prisma plus accentstapel
  - kontextmeny (`DockMenu`) skriver `dock.pinned` via Config (fäst, lossa, flytta)
  - tooltips är `BPopup` utan focus grab
- **OSD** (`Modules/Osd/`): material `osd`, klickgenomsläpplig (tom mask), reagerar på `Audio.changed` och
  `Brightness.changed`.
- Nya tjänster: `Audio`, `Brightness`, `NetworkStatus`, `BluetoothStatus`, `Vpn`, `Power`, `Media`, `Apps`.
  Leverantörsspecifik kod (piactl, nmcli, brightnessctl, ddcutil, powerprofilesctl) finns bara i respektive tjänst.
- Inga nya material har skapats. Launcher och control center använder `panel`, docken `dock`, OSD `osd`,
  menyer `popover` och tooltips `tooltip`.

## 10d. Notiser, låsskärm, power-meny, nested (fas 6)

- `Services/Notify.qml`:
  - skapar `NotificationServer` bara om `RunMode.ownsNotifications` och `notifications.server`
  - popups (max `notifications.maxVisible`; kritiska visas även i "Stör ej"), historik (max `historyLimit`), oläst-räknare
  - popup-timeout döljer bara popupen, notisen ligger kvar i historiken; stäng = `dismiss()` till avsändaren
- `Services/Session.qml`: lås, logga ut, vänteläge, omstart, avstängning med spärrar per körläge
  - overlay: inget
  - nested: lås och logga ut (bara den nästlade instansen)
  - production: allt
  - utloggning går via `Compositor.exitSession()`
- `Modules/Notifications/`: `NotificationCard` (gemensamt), `NotificationPopups` (mask på korten, hover pausar
  timeout), `NotificationCenter` (panel som control center).
- `Modules/Lock/`: `WlSessionLock` + `PamContext`, bara när körläget äger session lock. `LockSurface`: mörk bakgrund,
  svag aurora-glöd nedtill, märket som vattenstämpel, `hero`-klocka och upplåsningskort (material `lock`).
- `Modules/PowerMenu/`: panelglas i mitten, piltangenter/Enter/Esc, destruktiva val kräver ett andra klick
  (`power.confirm`). Spärrade val visas inaktiverade med förklaring.
- IPC: `notifications` (toggle, clear, dnd), `lock` (lock, isLocked), `power` (toggle) och `wm` (fönsteråtgärder via
  compositor-fasaden; används för tangentbindningar och tester).
- `scripts/nested.sh` + `hypr/nested.lua`: nästlad Hyprland med egen D-Bus; där äger Bifrost notiser och session lock.
  Utifrån nås den med `HYPRLAND_INSTANCE_SIGNATURE=<nästlad>` (hyprctl), `WAYLAND_DISPLAY=<nästlad>` (qs ipc, grim)
  och den nästlade bussens `DBUS_SESSION_BUS_ADDRESS` (notify-send).

## 10e. Bakgrundsbild och teman (fas 7)
- `Modules/Wallpaper/`: bakgrundslager per skärm med övertoning, bara när `RunMode.ownsWallpaper`
  (nested/production). Valet görs i Settings med miniatyrer ur `wallpaper.directory`.
- Teman: `bifrost-graphite` och `bifrost-fjord`, båda med mörk och ljus variant. En ljus variant överstyr opacitet,
  glas (depth, density, highlight), material-opacitet och skuggor. Egna och konverterade teman läggs i
  `~/.config/bifrost/themes/` och syns i temaväljaren.

## 11. Övergång till production (fas 8)

- `bifrostctl hypr generate --write` skriver `~/.config/bifrost/hypr/bifrost.lua`. Innehåll:
  - utseende bara om `hyprland.manage`
  - layer rules för `bifrost:*` om `hyprland.layerRules`
  - tangentbindningar till Bifrost-IPC om `hyprland.keybinds`
  Filen verifieras med `Hyprland --verify-config` via en temporär wrapper. Settings → Avancerat → Övergång visar den.
- `bifrostctl doctor --production`: kontroller inför bytet, som bara läser.
- `systemd/bifrost.service` (`Conflicts=dms.service`, `BIFROST_RUN_MODE=production`) installeras inte automatiskt.
- `docs/SWITCHOVER.md`: manuella, reversibla steg.
  - Installera tjänsten.
  - Säkerhetskopiera `hyprland.lua` och ersätt `require("dms.binds")` med `dofile(…bifrost.lua)`.
  - Byt tjänst. Backa samma väg; det finns också en räddningsväg från TTY.
- Bifrost skriver aldrig i `~/.config/hypr/`. Bytet görs av användaren.

## 12. Färdplan

| Fas | Innehåll | Status |
|---|---|---|
| 0 | Inventering, struktur, arkitektur | ✅ |
| 1 | Compat, dependencies, compositor-abstraktion, Core (schema/config/tema/apply-state), IPC, bifrostctl + doctor, selftest, dev.sh | ✅ |
| 2 | GlassSurface, StateLayer (solid/prism/ring), Controls, typografi, ikonset, galleri; standardglas godkänt | ✅ |
| 3 | Bifrost Settings: navigation, schema-genererade sidor, reset, sök, pending-banners | ✅ (väntar på granskning) |
| 4 | Bar + workspaces + klocka + tray + systemmonitor | ✅ |
| 5 | Launcher, control center, dock, volym-/ljusstyrke-OSD | ✅ |
| 6 | Notiser, lock, power-meny; `scripts/nested.sh`; Hyprland-åtgärder verifierade | ✅ |
| 7 | Wallpaper/teman, presets/profiler, import/export, DMS-import, notishistorik | ✅ |
| 8 | `bifrost.lua`-generator, `doctor --production`, `bifrost.service`, SWITCHOVER.md, Settings-sida | ✅ (väntar på granskning) |
| 9 | Niri-backend, väder, media-/batteriwidgets, drag-and-drop i dock, efter att användaren kört Bifrost i production | förslag |

## 13. Stabilisering 2026-09-25 (system som ersätter delar av §6, §10 och §10b)

- **Settings-livscykel**: ett residenskt fönster; `open` = visa + fokusera (`Compositor.focusProcessWindow`),
  stäng = dölj; `scripts/settings.sh` verifierar `status.mapped` och ersätter bara en trasig instans.
- **Keybindings**: `hypr/keybinds.json` → `bifrostctl` → `~/.config/bifrost/hypr/bifrost.lua` (unbind före bind,
  namngivna regler med `set_enabled`), tillämpas live av `Modules/CompositorSync.qml` (`bifrostctl hypr apply`) för
  alla inställningar med scope `hyprland`.
- **Installation**: `install.sh` (se HANDOFF §2), wrappers i `bin/`, `scripts/env.sh` (QS_ICON_THEME).
- **I18n**: `Core/I18n.qml`, engelsk källa, `i18n/<lang>.json`, systemets språk.
- **Theme mode**: `Core/ThemeMode.qml` (+ `Sun.js`) → `Theme.variant`; `Modules/SystemAppearance.qml` →
  `bifrostctl appearance apply` (portal, GTK, qt6ct/qt5ct, ikontema).
- **Ikoner**: `bifrostctl icons index` → `Compat/IconLookup` → `Platform.iconPath` (live), `Core/IconTheme.qml`.
- **Density & mått**: `themes/_base.json` `density`, `ThemeLogic`, `Core/Metrics.qml`.
- **Glass & material**: `schema/materials.json` (mall: all + per yta), `ThemeLogic.applyMaterial`, `glass-frame.frag`
  (fasning, refraktion, glöd, hål), blur per layer-namespace i `bifrost.lua`, `Settings/MaterialsPage.qml`.
  Upplösning: `ThemeLogic.materialValue` ↔ `bifrostctl material_value` (egen → All surfaces; `materials.link` = bara All).
  Blur 0–100 per yta, compositorns styrka = max. Blurmask: `ignore_alpha` per namespace = `material.blurMask`, som
  `glass-frame.frag` respekterar (kropp över, skugga/glöd under); Settings-fönstret klipps med fönster-`rounding` (max 20).
- **Bar**: `bar.style` floating/attached, `bar.background` panel/subtle/none, `bar.widgetStyle`
  integrated/boxed/grouped, `bar.layout` bar/frame (frameGlass med hål, `FrameReserve`), menyer växer ur det glas de
  öppnas från (`GlassSurface.stripY/stripHeight`, fristående glas om inget finns).
- **Popups**: PopupGroup + HoverIntent + LeaveWatch + MenuHost + BPopup; `bar.menus.openOnHover` gäller alla menyer.
- **Sidobar (vänster/höger)**: `BarWindow.view` är topp-/bottenbaren vriden 90° medurs (vänster = bottenlayout, höger =
  topplayout). Allt i `view` är i "bar-koordinater"; `BarWindow.windowRect()` mappar tillbaka (båda hörnen). Input-masken
  är `MaskRect`-regioner med x/y/w/h (Quickshells `Region{item}` fungerar inte under rotation). `WidgetHost` och `BarMenu`
  (`face`) vrider tillbaka innehållet med heltalstransformer; widgets läser `vertical`, anger längd som `implicitHeight`
  (`BarWidget.length`) och använder `BarRow` (Grid som blir kolumn). `Metrics.barEdge/barVertical/edgeSpace()/panelInset()`
  används av CC, notiscenter och notis-popups.
- **Klockmenyn**: `Widgets/ClockMenu.qml` (BarMenu) + `Shared/MonthCalendar.qml` + `Services/Weather.qml` (Open-Meteo,
  retain/release, status off/nolocation/loading/ok/offline/error, `stale`) + `Media` (position/längd).


## Continuation 2026-09-26

- `Theme.windowRadius` and CLI `window_radius` resolve explicit window rounding or
  the active theme radius; the frame hole uses this, with square outer glass.
- Power adds native UPower aggregate battery state. Media adds an optional MPRIS
  bus-name selection. Widgets consume these services; clock/widget share MediaPanel.
- Dock and Launcher reuse Shared/AppMenuContent; the launcher popup stays within
  its existing surface so focus grabs do not dismiss the parent panel.
- Theme catalog data operations remain in bifrostctl, using tools/theme_catalog.py
  to validate and convert Tinted palettes to ordinary Bifrost themes. No second
  runtime theme engine. Active user-theme files are watched by Core/Theme.

### Network management
NetworkStatus owns native scanning plus one nmcli monitor and shared profile/interface state. NetworkPage and VPN use that service. Profile commands pass structured argv; hidden-network credentials go through Exec stdin to tools/network_hidden.py and NetworkManager AddAndActivateConnection. No credentials are stored in Bifrost config.

### Dock layout and frame joins
DockGeometry computes screen-relative rects for four edges and a clamped free position. A full-screen input-masked dock surface keeps geometry stable; a separate reservation surface handles edge workarea. ShellState registers dock windows so each frame can render its dock and dock-panel joins in one glass shader pass (GlassSurface attachment2/attachment3, constrained inside the screen). GlassJoin transforms joins for all four directions. In free mode the standalone dock material and drag handle are used; config stores normalized coordinates.

### Foreground and shadow controls
ThemeLogic applies optional per-variant appearance.foreground overrides before token references resolve, covering text and monochrome icons. Semantic status and app artwork are unchanged. Layer shadow alpha thresholds scale with the configured shadow multiplier in both ThemeLogic.blurMaskFor and bifrostctl.blur_mask; an in-window material preview has no layer alpha mask. SettingsScroll centralizes the mouse-wheel step while leaving pixel-based touchpad events to Flickable.
