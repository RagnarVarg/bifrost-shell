# Bifrost Shell – handoff

**Senast uppdaterad: 2026-09-26 (auto-hide verifierad efter login; clean-install-test nedan).** FAS 1–6 klara; FAS 7 #31 och FAS 8 #32 klara i kod (se §0). §1–§9 nedan är
historik – **§0 är den aktuella prioriteringslistan**. Loggposterna sist i filen är nyare än §1–§9.
Obs: flera sessioner (Claude/Codex) har arbetat parallellt i repot samma kväll – stagea bara egna filer, aldrig `git add -A`.

Läsordning: `CLAUDE.md` → den här filen → `docs/ARCHITECTURE.md` → `git log --oneline`.
Originalplanen (36 punkter i FAS 1–10) finns i användarens meddelande från 2026-09-25. Punkterna refereras här med nummer (#1–#36).

---

## 0. Aktuellt läge och prioriteringar (2026-09-26 kväll)

Klart denna session (tester: selftest 497/497, CLI 38/38, validate ok):
- `150270a` Systemstatus-klick = `bifrost-terminal btop` (terminaloberoende; wrappern väljer rätt flagga per terminal),
  shellets `bin/` i PATH via `scripts/env.sh`. Nytt default gäller efter omstart.
- `2b66a61` **#31 OSD:** mic-OSD följer mute oavsett källa (mic-off-ikon), media-tangenter visar åtgärd + spår (`osd.media`).
- `6e7e9a1` **#32 Bluetooth:** parningsagent (`tools/bt_agent.py`, BlueZ Agent1 KeyboardDisplay) + prompt i shellet
  (`Modules/Bluetooth/PairingAgent`). Scan/pair/connect/forget fanns redan. End-to-end-test mot falsk BlueZ.
- `69f8348` **Polkit-agent** (fanns ingen i sessionen!) via Quickshell `PolkitAgent`; gemensam `Modules/Prompt/SystemPrompt`.
  Verifierat i production med `pkexec true` (prompt visas, avbryt → "Request dismissed").
- `7f8564d` sista hårdkodade UI-strängarna översatta.

**Kräver omstart av production** (`systemctl --user restart bifrost.service`, fråga användaren): `ShellState.showMediaOsd`
(singleton) – tills dess ger medietangenter ett ofarligt TypeError efter att åtgärden utförts; `osd.media`-schemat;
nytt systemstatus-default.

Fel (från `443e2b1`, annan session): genererad `bifrost.lua` innehåller `hl.timer(...)` (VRR-omappning) →
`Hyprland --verify-config` segfaultar vid avslut (exit 139, coredumps 21:20) → `bifrostctl hypr verify` rapporterar fel
med användarens config. **Rättat** (timern hoppas över när `__bifrost_verify` är satt; användarens fil regenererad,
`hypr verify` ok; regressionstest).

Efter omstart 21:35 (användaren testade: BT-parning med kod, polkit, medietangenter – alla fungerar):
- `30f76d9` + `14cba08` **Kortkommandoeditor** (Settings → Keybindings → Shortcuts). Backend bara i bifrostctl:
  standardbindningar har stabila id:n (`hypr/keybinds.json`), `keybinds.overrides` (id → tangenter, "" = av),
  `keybind_entries()` = enda katalogen (standard, egna, externa skrivskyddade från `hyprctl binds -j`), konflikter via
  kanonisk form (`canon_keys`/`keys_id`). `bifrostctl keybinds list|check|set|off|reset|add [--force]`. Generatorn ger
  identisk fil för användarens config. Inspelning: `Compositor.setKeyCapture` = tom Hyprland-submap
  `bifrost-capture` (Super+Esc lämnar alltid), testad i nested; **riktiga tangenttryck ej provade**.
- `7250b37` **Skärmtimeout** (Settings → Power → When idle): släck skärm / lås / vila separat (Aldrig…1 h, standard
  Aldrig), `power.idle.respectInhibitors`. `Modules/Idle` (IdleMonitor, ny monitor per värde), `Compositor.setDisplaysPower`
  (dpms); generatorn slår på Hyprlands `*_enables_dpms` när skärmtimeout är på. Verifierat i nested.
- **Kräver omstart av production** (fråga): Compositor-singleton (`setKeyCapture`, `setDisplaysPower`), schemat
  (`keybinds.overrides`, `power.idle.*`); Settings-processen likaså.

- `e2d0167` **Greetd-greeter (byggd och testad, INTE installerad/aktiverad)** – planen godkänd av användaren 2026-09-26:
  `shell/greeter.qml` + `shell/Greeter/`, launcher `greeter/bin/bifrost-greeter` (minimal Hyprland via start-hyprland,
  reserv = dms-greeter när inloggningen inte skett), `greeter/hyprland.lua`, `greeter/session.sh`,
  `bifrostctl greeter sync|status` → `/var/cache/bifrost-greeter` (kopior, inga symlänkar), `Modules/GreeterSync`,
  `greeter/install-greeter.sh` (install | --enable | --disable | --status | --uninstall; backup av config.toml).
  Nuvarande greetd: `dms-greeter --command hyprland --cache-dir /var/cache/dms-greeter` (läser DMS-filer via symlänkar).
  Test: `scripts/greeter-test.sh <scratch>` (nested + `tools/dev/fakegreetd.py`, `BIFROST_GREETER_DRYRUN=1`).
  Verifierat: lyckad/misslyckad inloggning, tvåstegsfråga, användar-/sessionsbyte, minne, layoutbyte, ström (torrkörd),
  stor text, hög kontrast, utan avatar/wallpaper/temadata, reserv (saknade filer, SIGKILL, SIGSEGV), installerad kopia,
  enable/disable återställer config.toml identiskt (scratch). **Väntar på användarens godkännande av utseende + reserv**
  innan `sudo greeter/install-greeter.sh` och `--enable`.
  Incident: `transient` är reserverat i QML – Config.qml gick inte att ladda i ~18 s (production behöll förra versionen).
  **Kompilera Core-ändringar (selftest) innan de sparas i det live-länkade repot är inte möjligt – håll dem minimala.**

- 2026-09-26 22:40: utseendet godkänt (`c437b86` datumskugga). **Installerat** av användaren (`sudo greeter/install-greeter.sh`)
  → `/usr/share/bifrost-greeter` (root, världsläsbart), `/var/cache/bifrost-greeter` (root:greeter 2775, `state/`
  greeter:greeter 0770), `bifrostctl greeter sync` körd. `/etc/greetd/config.toml` oförändrad (sha256 5739d47b…),
  greetd använder fortfarande dms-greeter. Installerad kopia testad i nested mot en kopia av cachen.
  Den installerade `shell/selftest.qml` har ännu gammalt testunderlag med personnamn (rättat i `63ce395`, används inte av
  greetern) – försvinner vid nästa `sudo greeter/install-greeter.sh`.

- 2026-09-26 ~22:48: **Greetern aktiverad och live-testad – KLAR.** Användaren körde `--enable`; `/etc/greetd/config.toml`
  har `command = "/usr/share/bifrost-greeter/bin/bifrost-greeter"`, `user = "greeter"`. Användaren loggade ut, Bifrost-greetern
  visades korrekt, riktig inloggning fungerade och Hyprland + Bifrost startade normalt (greetd-session 22:48:20,
  `bifrost.service` aktiv 22:48:21, `state/memory.json` skriven). **Ändra inte greetern utan konkret fel.**
  dms-greeter är kvar som reserv (startas av bifrost-greeter när inloggningen inte sker); rollback
  `sudo greeter/install-greeter.sh --disable` (+ `sudo systemctl restart greetd`), nödväg Ctrl+Alt+F2.

- 2026-09-26 ~23:00: **Dockens auto-hide dog efter login (regression, rättad `cae1c7b`, väntar på login-test).**
  Config var rätt (`dock.autohide` true, `smartHide` true). Men `bifrost compositor` visade `monitors: []`, ingen aktiv
  workspace och fönster med workspace −1 → `windowsCover` alltid false → smart-hide höll docken framme. Orsak: `hyprland.lua`
  startar `hyprland-session.target` medan Hyprland laddar sin config; qs startade 22:48:20, Hyprlands request-socket kom
  22:48:21.36. Quickshell 0.3.1 skapar monitorer/workspaces bara från sitt första IPC-svar eller `monitoraddedv2`
  (`Hyprland.refreshMonitors()` från QML = `refreshMonitors(false)`, skapar inget) → tomt hela sessionen
  (journal: "Got openwindow for workspace "1" which was not previously tracked"). Fix: `bin/bifrost-shell` väntar (max
  ~10 s) tills `hyprctl monitors -j` har `activeWorkspace`; `HyprlandBackend.trackingCheck` loggar fel efter 5 s om
  Quickshell fortfarande saknar monitorer. Restart av tjänsten återställde tillståndet (DP-2, ws 2).
  Direkt session = greetd → `start-hyprland` (inte UWSM; `hyprland-uwsm.desktop` finns men är otestad).
  *Nested gick inte att använda som test:* Quickshell ser 0 monitorer i nested även när den startas sent (hyprctl ser dem).
  **Avslutat:** `a60f441` rättar dessutom backendens initialiseringsrace. Användaren har verifierat både Dock och top bar efter logout/login; se senaste loggpost.

Prioriteringar framåt:
1. ~~Greetern~~ klar (se ovan). Installern erbjuder nu greetern i stället för saknat SDDM-tema (`75f3c50`, #35).
2. Manuella tester efter omstart: spela in kortkommando (även upptaget, t.ex. Super+Q), skärmtimeout på riktigt.
3. #33 Display (HDR/10-bit/färgprofiler, Display-sidan) – **lämnad till den andra sessionen**; rör inte.
4. FAS 10: #35 isolerad kopieinstallation/uppdatering/avinstallation verifierad med tools/test_install.py; riktig ny användarsession återstår. #36 sluttest återstår.

## 1. Läget i ett nötskal

- **Bifrost är användarens riktiga session-shell.**
  - `dms.service` är stoppad. `bifrost.service` är aktiverad och körs.
  - Installationen är en `--link`-installation: `~/.local/share/bifrost-shell` är en symlänk till `~/Projects/bifrost-shell`.
    Ändringar i repot slår därför igenom direkt (QML laddas om av Quickshells filbevakare). Schemaändringar, shaderändringar
    och nya singletons kräver `systemctl --user restart bifrost.service`.
- **`~/.config/hypr/hyprland.lua` laddar Bifrost.** Installern lade till ett block sist i filen och kommenterade bort
  `require("config.bifrost-binds")`. Backup finns i `~/.config/hypr/hyprland.lua.before-bifrost.<ts>`. Blocket ser ut så här:
  ```
  -- BIFROST_BEGIN (added by the Bifrost installer; remove this block to unhook)
  dofile(os.getenv("HOME") .. "/.config/bifrost/hypr/bifrost.lua")
  -- BIFROST_END
  ```
- **Config** `~/.config/bifrost/config.json` är nu **version 5** (migrerad live 2026-09-26 13:40; backup `backups/config.v4.1790422831590.json`). Backups för varje migrering ligger i `~/.config/bifrost/backups/`.
- **Tester:** `scripts/selftest.sh` ger **381/381** och `tools/test_bifrostctl.py` ger 21/21. `bifrostctl validate` ger ok.
- **Production-shellet startades om 2026-09-26 13:19** (av användaren/inloggning), före sessionens ändringar. QML laddas om live,
  men **`glass.frag` (blurmasken) och schemat (`materials.link`, blur 0–100) kräver `systemctl --user restart bifrost.service`**.
  Fråga användaren först.

## 2. Faser: status och commits

| Fas | Status | Commits |
|---|---|---|
| Baslinje (förra sessionens ocommittade arbete) | committad som den var | `cc8ceff` |
| FAS 1 – stabilitet, Settings, grundarkitektur | **klar** | `a2b0532`, `25f4c10` |
| FAS 2 – theme, språk, ikoner | **klar** | `6e48c02`, `6c9fc4c` |
| FAS 3 – material/glass | **klar** (#12–#19) | `59d66d0`, `7a03147` |
| FAS 4 – popup/menu-manager | **klar** (#20–#21) | `1d87c04` |
| FAS 5 – topbar och frame | **delvis klar**: frame topp/botten (#22), vänster/höger (#22) och klock-popup (#23) workspace preview (#24) och VPN (#25) klara; frame-test i production återstår (nested klart) | `b90310e`, `1e06c41`, `8597ae6` |
| FAS 6–10 | inte påbörjade | – |

### FAS 1 (#1–#5)
**#1 Settings-zombie**
- *Rotorsak:* Settings är ett `FloatingWindow`. En stängning från compositorn (Super+Q eller titelraden) döljer fönstret
  (Quickshell emitterar `closed` och sätter `visible=false`), men processen lever kvar. IPC `settings open` anropade bara
  `SettingsNav.open()` och satte aldrig `visible`, så inget syntes.
- *Fix i `shell/settings.qml`:*
  - `shown`-state, `present()` och `hide()`. Esc, × och `onClosed` döljer bara fönstret.
  - `open` visar fönstret och fokuserar det via `Compositor.focusProcessWindow(pid)`, en ny facade-metod.
    I Hyprland blir det `hl.dsp.focus({ window = "pid:N" })`.
  - Nya IPC-funktioner: `status` (JSON med `mapped`) och `quit`.
- *`scripts/settings.sh`:*
  - Anropar `open` och pollar `status` tills fönstret är mappat, i högst 2 s.
  - Instanser som inte svarar eller inte kan mappa sitt fönster avslutas (via `qs list -p … -j`) och startas om med `qs -n -d`.
  - Körläget ärvs från det körande shellet (`bifrost ping` → `pong <mode>`).
- *Testat:*
  - 20 cykler öppna/stäng växelvis med IPC-close och compositor-close: 0 fel, samma pid.
  - 10 cykler via shellets `openSettings` (samma väg som Control Center-knappen) och `bifrost-settings`: 0 fel.
  - Fokus när ett annat fönster hade fokus: rätt.
  - SIGSTOP-hängd instans: ersattes efter cirka 5 s.
  - Dold i över 5 minuter och sedan öppnad: samma pid.

**Keybinds (P0 #28–#30, gjorda i FAS 1 eftersom de var blockerande)**
- *Rotorsaker:*
  - `bifrost-ipc` och `bifrost-settings` fanns inte i PATH. Hyprlands PATH saknar dessutom `~/.local/bin`.
  - Super+T var bunden två gånger i den handgjorda `config/bifrost-binds.lua`.
- *Keybinding-system:*
  - `hypr/keybinds.json` är den enda källan (grupper: shell, media, screenshots, windows, workspaces).
  - `bifrostctl` genererar binds i `~/.config/bifrost/hypr/bifrost.lua` med `pcall(hl.unbind, keys)` före varje `hl.bind`,
    och spårar bundna tangenter i `_G.__bifrost.binds`. Filen är idempotent och kan köras live med `hyprctl eval dofile(...)`.
  - Siffertangenterna genereras utifrån `keybinds.workspaceStyle` (`focus` eller `moveFollow`).
  - `keybinds.custom` är en lista med strängar på formen `"KEYS: ipc …|run …|dispatch …"`. `keybinds.disabled` är en lista med tangenter.
- *Användarens tidigare egna binds är migrerade till `keybinds.custom`:* Super+X → CC, Super+A → notiser, Super+L → lås,
  Super+Alt+C → power, Super+Z → Settings, Super+F → fullscreen, Super+Alt+Space → float. `workspaceStyle` är `moveFollow`.
- *Verifierat:*
  - `hyprctl binds` visar inga dubbletter bland namngivna tangenter och exakt en Super+T.
  - Varje bundet kommando kördes med Hyprlands egen PATH: launchern togglar, volym och mute fungerar, en terminal öppnas.
  - **Riktiga tangenttryck har inte kunnat testas.** uinput kräver gruppen `input`, och `ydotool.service` är trasig.
    Användaren behöver själv trycka Super+Space, Super+T, volym- och mediatangenter.

**Wrappers i `bin/`** (symlänkade till `~/.local/bin` av installern):
- `bifrost-ipc`, `bifrost-settings`, `bifrost-shell` (används av tjänsten), `bifrost-terminal` och `bifrost-screenshot`
  (region, full eller window; grim, slurp, wl-copy och notify-send).
- De följer bara symlänken i `~/.local/bin` ett steg. Då blir runtime-sökvägen `~/.local/share/bifrost-shell` även för en länkinstallation.

**`install.sh`**
- Flaggor: `--link`, `--yes`, `--no-hypr`, `--no-sddm`, `--no-enable` och `--uninstall`.
- Kopierar till `$XDG_DATA_HOME/bifrost-shell` med rsync. `--link` symlänkar i stället.
- Länkar kommandona och installerar `systemd/bifrost.service`. Mallen innehåller `@EXEC@`, som ersätts med
  `%h/.local/share/bifrost-shell/bin/bifrost-shell`.
- Genererar `bifrost.lua` och hookar in den i `hyprland.lua` efter att ha frågat (med backup).
- Installerar nu bundlat FullBlue till `~/.local/share/icons` om temat saknas, och skapar desktop-entry för Settings.
- SDDM-steget anropar `sddm/install-sddm.sh`, **som ännu inte finns** (FAS 9).
- Testat i scratch-HOME (en ny användare) och avinstallationen testad. Inga personliga sökvägar i genererade filer.

**CompositorSync** (`shell/Modules/CompositorSync.qml`, bara i production)
- Varje ändring av en inställning med scope `hyprland` kör `bifrostctl hypr apply --json`. Det gäller också
  `appearance.accent`, `theme`, `mode`, `radiusScale` och ändringar av ljust/mörkt.
- Resultatet skrivs till `$XDG_RUNTIME_DIR/bifrost/compositor.json`.
- Verifierat live: gaps, rounding, border 8 → 3 → 8, transparens för aktivt och inaktivt fönster, blur och binds på/av.
  Allt syntes direkt i `hyprctl getoption`/`binds`.

**#2 Avancerat-sidan**
- Hyprland-inställningarna var placebo: `bifrost.lua` laddades aldrig.
- Nu finns System → "Windows & compositor": gaps, fönsterkant, fönsterradie, transparens för aktivt och inaktivt appfönster
  samt integration. Kategorin Avancerat är borttagen.
- Blur-reglagen flyttades till Glas & material i FAS 3.

**#3** Sidan "Övergång" är borttagen. DMS-importen finns kvar under Import & export och visas bara om
`bifrostctl import-dms --detect` hittar DMS-filer.

**#4 Density**
- `appearance.density` (compact, standard, spacious) med token-block `density` i `themes/_base.json`.
- `ThemeLogic` skalar space, kontrollhöjder, fält, chips och ikonstorlekar. `Core/Metrics.qml` är den enda källan för
  panelmått (bar-höjd, marginal, spacing, dock-ikoner, launcher-ikoner, `barSpace`, frame).
- Presets Compact och Spacious väljer nu density.
- *Rotorsak till att skillnaden inte syntes tidigare:* presets är ett baslager *under* användarens egna värden.
- Verifierat med skärmdumpar av baren i alla tre lägena.

**#5 Apply-lägen**
- Radnoten och bannrarna för reload och restart finns. Restart-bannern har en knapp: IPC `bifrost restart` →
  `systemctl --user restart bifrost.service`, bara när `INVOCATION_ID` finns (körs av systemd). Annars visas en förklaring.
- Ikontema är nu live, inte restart.

**Settings-fönstret** är flytande, centrerat, 1180×820, utan Hyprland-kant och skugga (fönsterregel i `bifrost.lua`).

### FAS 2 (#6–#11)
**#6 Translation**
- `Core/I18n.qml` med `tr(text, n)`, som väljer `one`/`other` och ersätter `%n`. `%1` använder QML-strängens `.arg()`.
- Språket väljs som i gettext: `LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG`. `BIFROST_LANG` överstyr (selftest använder `en`).
- Källspråket är **engelska**. `i18n/sv.json` innehåller cirka 470 poster. Schemat localiseras i `Schema.localize` vid laddning.
- Testet `test_swedish_translation_is_complete` kräver att varje schematext, mallinstans och `I18n.tr("…")`-literal finns i `sv.json`.
- **Användarens system har `LANG=en_GB`, så Bifrost visas på engelska.** Det följer kravet (följ systemspråket).
  Svenska verifierad med `BIFROST_LANG=sv` (skärmdump).

**#7–#8 Ikoner**
- *Rotorsak:* Quickshell körs med `QT_QPA_PLATFORMTHEME=qt6ct`, och `~/.config/qt6ct/qt6ct.conf` hade `icon_theme=YAMIS`.
- *Lösningen:*
  - `bifrostctl icons index THEME` bygger en freedesktop-uppslagning (`Inherits`, hicolor, pixmaps, skalbart och storleksval)
    och cachar den i `~/.cache/bifrost/icons/<tema>.json`.
  - `Compat/IconLookup` håller indexet och `Platform.iconPath()` slår upp där först. Tray- och notis-ikoner (`image://icon/…`) går samma väg.
  - `Core/IconTheme` laddar rätt index live.
  - `appearance.icons.theme`: tomt = Gruvbox-Plus-Dark-IceBlue-FullBlue i båda lägena; `"system"` = skrivbordets tema; annars det namngivna temat.
  - `scripts/env.sh` → `bifrostctl env` exporterar `QS_ICON_THEME` vid start.
- Användarens explicita `Nordzy-dark` återställdes till standardvalet, som då gav Nordzy-dark i mörkt läge (historik; nu FullBlue).
- Verifierat med dock-skärmdumpar: Nordzy → Papirus → Nordzy live, utan omstart.

**#9** HSV-väljare (`Components/Controls/BColorPicker.qml`) i `ColorEditor`, med HEX, snabbval och "Bifrost default".
En egen accent härleder `accentDeep` och `accentText` (WCAG-kontrast, tröskel L > 0,179).

**#10–#11 Theme mode**
- `appearance.mode`: light, dark, system eller auto. `Core/ThemeMode.qml` bestämmer ljust eller mörkt.
  - system följer `gsettings color-scheme` via `Compat/LineWatcher` (`gsettings monitor`).
  - auto använder `Core/Sun.js` (NOAA). Platsen kommer från `appearance.location.*` eller tidszonens koordinater i `zone1970.tab`/`zone.tab`, helt offline.
- `Modules/SystemAppearance.qml` (bara i production, och inte i system-läget) kör `bifrostctl appearance apply --variant V`.
  Det sätter portalens color-scheme, GTK-temats motsvarighet (MacTahoe-Dark ↔ Light), GTK3/4 `settings.ini`,
  qt6ct/qt5ct (ikoner och Kvantum dark ↔ light) och gsettings `icon-theme`. En egen Qt-palett rörs inte.
  Resultatet skrivs till `$XDG_RUNTIME_DIR/bifrost/appearance.json`.
- Engångsbackup av främmande filer i `~/.config/bifrost/backups/system/`.
  **qt6ct och gtk-3.0 ändrades innan backupfunktionen fanns**, så originalen är rekonstruerade: `icon_theme` respektive
  `gtk-icon-theme-name` var `YAMIS` (se `README.txt` där).
- Verifierat:
  - Växling ljust ↔ mörkt ändrade alla mål i production.
  - Auto med Los Angeles-koordinater gav ljust, Stockholms tidszon gav mörkt (kväll).
  - Solberäkningen stämmer mot en oberoende algoritm: Stockholm 2026-09-25 upp 04:39 och ned 16:39 UTC.

### FAS 3 (#12–#19)
**Materialsystemet** (`schema/materials.json`)
- Schemat har en **mall** som expanderas av `Schema.qml expandTemplate` och `bifrostctl expand_template`. Båda måste hållas identiska.
- 13 egenskaper för `materials.all.*` och för varje yta: `bar`, `dock`, `menus` (popover och tooltip), `launcher`
  (samt power), `controlCenter`, `notifications`, `settings` och `osd`. Ytorna ärver från all och sedan från temat.
- Egenskaperna: transparency, blur, tint, thickness, grain, refraction, glow, border, borderWidth, borderOpacity,
  borderColor, radius och shadow. Dessutom `materials.blurStrength`.
- `ThemeLogic.applyMaterial` skriver `m.effective` (det som Settings visar för tomma värden) och nya materialfält:
  bevel, bevelStrength, refraction, glow och thickness.
- Materialen `launcher`, `controlCenter`, `notifications` och `settings` finns och klonas från `panel` om ett tema saknar dem.

**Shader och editorer**
- `glass.frag` har fasad kant (tjocklek), refraktion (simulerad caustic och färgdelning; bakgrunden går inte att sampla),
  prisma-glöd och hål (frame).
- `prism.frag`: intensiteten styr täthet, kantbredd och inre glöd. 0 = av (tillståndet faller tillbaka till solid fyllning).
- **Nullable bool** är tillåten, och BoolEditor har tre lägen (chipet "Inherit").
- `EditorBase.fallback` och `SettingRow.fallback` visar det effektiva värdet. `inheritKey` finns också.

**Blur per yta** är riktiga layer rules per namespace i den genererade filen (`layer_rule("bifrost-blur-<ns>")`).
- De ersätts via handtag (`rule:set_enabled(false)`) i `_G.__bifrost.rules`.
- Settings-fönstret styrs av fönsterregeln `no_blur`.
- Blurstyrkan mappas till Hyprlands size och passes. Standardvärdet 5 ger 3 och 2, alltså det godkända utseendet.
- Verifierat: launchern med blur av visar skarp text bakom, med blur på är den oläslig (kantenergi 11,18 mot 4,05).

**Settings → Glass & materials** (`Settings/MaterialsPage.qml`): chips för ytor, levande förhandsvisning och "Reset surface".

**#17** Kant- och radiekontroller per topbar och dock finns via ytorna.

**#18–#19 Baren**
- `bar.background` (panel, subtle, none) och `bar.widgetStyle` (integrated, boxed, grouped).
- `bar.style` har nu bara floating och attached. Islands migreras.
- Boxed ger en bubbla per widget, och systemstatus-gruppen blir en bubbla (`BarZone.bubbles`).
- Utan panel är bubblorna eller öarna baren: menyer växer ur dem. Utan någon glasyta alls får menyn eget glas (MenuHost).
- Skärmdumpar av alla sex kombinationer och av menyer (från en bubbla och fristående).
- **Kvar:** tray-ikoner inom `status` delar en bubbla; widget-bubblor per tray-ikon finns inte.

Verifierat visuellt: docken med tjocklek 0, 1 och 4, refraktion, glöd, 4 px röd kant och skugga 3 (skärmdumpar).
Prisma 0, 1 och 3 i galleriet.

### FAS 4 (#20–#21)
- Popup-hanteringen består av `PopupGroup` (en åt gången, `closeAll`, `justDismissed`), `HoverIntent`, `LeaveWatch`,
  `MenuHost` (bar-menyer) och `BPopup` (dock och dropdowns). Allt var redan gemensamt.
- *Rotorsak till #21:* `BarMenu.openOnHover` var `!grabFocus || setting`, så systemstatus öppnades alltid vid hover.
  Nu gäller inställningen alla menyer.
- Med hover av öppnar klick systemstatus med focus grab, och knappen "Open system monitor" kör `clickCommand`.
- Selftest täcker båda lägena.
- **Riktig mus är inte verifierad** för hover-övergångar inne i baren. Syntetisk hover finns inte i Hyprland, eftersom
  `cursor.move` inte ger rörelse inom samma yta.

**Hover-byte från Control Center blockerades** (`d342162`, rapporterad 2026-09-25 kväll)
- *Symptom:* med hover-öppning på låg CC kvar när pekaren gick vänster längs baren till en annan widget, tills pekaren
  lämnade panelens horisontella bredd.
- *Rotorsak 1 (input):* CC- och notiscenter-fönstren är glaset + skuggmarginal (`margins.top = panelInset − shadowExtent`).
  I production låg CC-lagret på y=14 medan baren är 0–62 (`hyprctl layers`), och overlay-lagret ligger över barens
  top-lager. Den transparenta marginalen tog alltså barens pekare inom panelens bredd → grannwidgetens `hovered` blev
  aldrig sann → ingen HoverIntent → inget byte. *Fix:* `mask: Region { item: glass }` på båda panelfönstren.
- *Rotorsak 2 (LeaveWatch):* CC:s `leaveRects` hade en brygga lika bred som panelen från barens topp, så
  compositor-kontrollen (`pointerInAny`) räknade andra barwidgets som "inuti". *Fix:* notiscentrets gap-geometri är nu
  `LeaveWatch.panelRects(panel, anchor, edge)` och används av båda panelerna.
- Bar-menyerna (MenuHost) hade inte problemet: de ritas i barens eget fönster och bredvid baren, inte över den.
- *Tester:* `panelRects`-fall i selftest (topp, botten, sidobar: annan widget = utanför, knapp/gap/panel = innanför) och en
  statisk kontroll i `tools/test_bifrostctl.py`: varje `PanelWindow` vars marginal dras in med `glass.shadowExtent` måste ha `mask:`.
- *Verifierat:* live-omladdning utan QML-varningar, CC och notiscenter öppnar/stänger via IPC.
- **Kräver manuell verifiering med riktig mus:** Hyprland har ingen syntetisk pekarrörelse som ger hover-events
  (`cursor.move` warpar utan motion inom samma yta, uinput/ydotool saknas, se FAS 1). Själva rörelsen CC → granne måste
  därför testas för hand: hovra CC, gå vänster längs baren till status/skärm/notiser → deras popup ska öppnas efter
  `bar.menus.hoverDelayMs` och CC stängas; upprepa åt båda håll och mellan flera widgets.

### FAS 5 (delvis klar)
**#22 Frame** (`bar.layout = frame`, `bar.frame.thickness`)
- BarWindow blir helskärm och ritar `frameGlass`, med hål och `stripY`/`stripHeight` så att menyer växer ur barsidan.
- Input-masken ligger bara på ramen. `Modules/Bar/FrameReserve.qml` ger fyra osynliga reservfönster (`bifrost:frame-reserve`).
- Autohide är av i frame-läge.
- Verifierat i scratch-instans (overlay) med baren nere: ram, rundade innerhörn och en meny ur barsidan (skärmdumpar).
- **Inte testat i production** (användarens config har `layout = bar`), inte heller exklusiva zoner och blur på frame-lagret.
- **Kvar:** positionerna vänster och höger (#22) finns inte, och `bar.position` är fortfarande `top|bottom`.

**#22 Vänster/höger bar** (`1e06c41`) – `bar.position` = top|bottom|left|right.
- *Beslut:* en sidobar är topp-/bottenbaren **vriden 90° medurs** (`BarWindow.view`: `Rotation{90}` + `Translate{x: width}`).
  Vänster = bottenlayout (`atBottom` true), höger = topplayout. MenuHost, frame, autohide-animation och FrameReserve
  återanvänds oförändrade. `BarWindow.edge`, `vertical`; `atBottom` betyder nu "layouten", inte skärmkanten.
- Widgets vrids tillbaka i `WidgetHost` (nu ett Item med inre Loader; `item`-alias och `loaded`-signal kvar) med
  heltalstransform så texten är skarp. `BarWidget.vertical` och `length` (= `implicitHeight` på sidobar, standard kvadratisk).
  `Widgets/BarRow.qml` = rad som blir kolumn (byter rows/columns i säker ordning, annars Grid-varning).
  Klockan staplas (HH/mm, d/MMM), workspace-pillren växer längs baren, systemstats/GPU staplas, fönstertiteln döljs på sidobar.
  Ikonknappar använder `anchors.fill: parent` (samma resultat horisontellt).
- `BarMenu` har `face` (menyn som den syns på skärmen) som motroteras; `menuWidth/menuHeight` byter plats; extra
  `topPadding` hamnar mot baren.
- **Viktigt:** Quickshells `Region { item }` mappar bara origo och bortre hörn (`mapToScene`) → fel under rotation.
  Masken är därför `MaskRect`-regioner med beräknade x/y/w/h (`BarWindow.windowRect`). `MenuHost.rectIn()` och
  `screenRect()` mappar båda hörnen.
- `Metrics.barEdge`, `barVertical`, `edgeSpace(edge)`, `panelInset(edge)`. CC och notiscenter ligger i hörnet vid barens
  ände (uppe till vänster för vänsterbar) och glider in från barens sida; notis-popups håller avstånd till sidobar/frame.
- *Verifierat i scratch-overlay (skärmdumpar):* vänster och höger bar, menyer (system, ljud, nätverk) som växer ut åt rätt
  håll med upprätt innehåll, frame med högerbar (rundade innerhörn), autohide gömmer vänsterbaren, CC bredvid vänsterbar,
  bottenbar oförändrad (regression), inga QML-varningar vid växling top→left→right→bottom.
- *Inte verifierat:* reveal med riktig pekare på sidokant, exklusiv zon för sidobar i production/nested, glasets ljus
  följer bandet (höger bar har högdagern mot skärmkanten, som toppbaren – medvetet accepterat).

**#23 Klock-popup** (`8597ae6`)
- `ClockWidget` är nu en `BarButton` som öppnar `Widgets/ClockMenu.qml` (BarMenu, bredd `Theme.layout.clockMenuWidth` 560).
  IPC: `bar statusMenu clock`.
- Innehåll: tid, långt datum, vecka; väder (nu + 3 dagar, "känns som", max/min, platsnamn från tidszonen);
  `Shared/MonthCalendar.qml` (lokalens veckostart, veckonummer om `clock.weekNumber`, pilar/hjul byter månad, klick på
  titeln → idag); media (omslag, titel, artist, progress, föregående/spela/nästa) om `Media.available`;
  knapp "Clock & date settings…" → `Launch.openSettings("clock")`.
- `Services/Weather.qml`: Open-Meteo via `XMLHttpRequest`, plats = `ThemeMode.location` avrundad till 2 decimaler,
  hämtar bara när menyn är öppen (retain/release, max 15 min gammal data, 10 s timeout). `status`:
  off/nolocation/loading/ok/offline/error; senaste data behålls och markeras `stale` ("Offline · senast uppdaterat HH:mm").
  Offline = `NetworkStatus.connected` false eller XHR-status 0/timeout.
- `Services/Media.qml`: `length`, `position`, `canPrevious/Next/Control`, `clock()`, retain/release som tickar
  `player.positionChanged()` varje sekund.
- Nya inställningar (schema/clock.json, grupp "Clock menu"): `clock.menu.weather` (true), `clock.menu.temperatureUnit`
  (celsius|fahrenheit), `clock.menu.media` (true). Inga migreringar behövs (defaults).
- Nya ikoner: `cloud`, `cloud-sun`, `cloud-rain`, `cloud-snow`, `cloud-fog`, `cloud-lightning`.
- *Verifierat:* skärmdump i scratch (bottenbar) med riktig väderdata (Stockholm 12° mulet), kalender med idag markerad och
  veckonummer, inga QML-varningar. Selftest: parse av Open-Meteo-svar, avvisning av trasigt svar, ikonmappning.
- *Inte verifierat:* mediapanelen visuellt (ingen MPRIS-spelare aktiv), offline-/error-lägena visuellt (bara logiken),
  klockmenyn på sidobar, Settings-knappen (skymdes av scratch-instansens dock i skärmdumpen), svensk text i menyn.

### Session 2026-09-26 (användarens extrapunkter 1–5)
1. **Hover-byte CC → annan barwidget** – `d342162` (mask + panelRects) löste det; nu **verifierat med riktiga pekarrörelser**
   i nested via ny virtuell pekare (`scripts/vpointer.sh`, `tools/dev/vpointer.c`, wlr-virtual-pointer) och
   `tools/dev/hovertest.py` (alla popup-par längs baren, även via panelen och med autohide): 62/62 byten ok.
   Nytt: `HoverIntent.switching` – när en barmeny/barpanel redan är öppen byts det **utan** `hoverDelayMs` (menyrads-beteende).
   IPC `bar widgets` ger widgetrektanglar + vad som är öppet (`menuFrom`). `scripts/selftest.sh` sätter nu `BIFROST_RUN_MODE=overlay`
   (terminaler startade från sessionen ärver `production`, vilket gav 4 falska fel). Commit `253b1a8`.
2. **Background Blur per yta** – `materials.<yta>.blur` är 0–100 (0 = av). *Begränsning (Hyprland 0.56):* blur är bara på/av
   per layer (`LayerRuleApplicator.hpp`: `DEFINE_PROP(bool, blur)`), styrkan är global. Användaren valde: **den starkaste
   påslagna ytan styr compositorns styrka**; Settings visar "Compositor strength now: N %" på blur-raden.
   `materials.blurStrength` är borttagen (migrering 4→5: av → 0, på → den gamla styrkan, `all.blur` = styrkan).
3. **Link all surfaces** – `materials.link`. Löses på ett ställe: `ThemeLogic.materialValue` ↔ `bifrostctl material_value`
   (länkat = bara All surfaces). Egna värden ligger kvar. Settings: toggle överst, chippen visar "linked", banner, raderna tonade
   och låsta med "Linked to All surfaces" och det länkade värdet (`SettingRow.linked/note`, `EditorBase.followsFallback`).
4. **Blur + rundade hörn** – två orsaker hittade:
   - *Skugga/glöd:* Hyprland blurrar där ytans alfa > `ignore_alpha` (0.01), så blur fyllde skuggzonen och klipptes rakt av
     fönsterkanten. Fix: gemensam tröskel (`themes/_base.json` `glass.blurMask` 0.01 / `blurMaskShadowed` 0.12 när glaset har
     skugga eller glöd). `glass.frag` håller kroppen över tröskeln och allt utanför under den (`material.blurMask`,
     `ThemeLogic.blurMaskFor` ↔ `bifrostctl blur_mask`, som skriver `ignore_alpha` per namespace). Pris: med blur på blir
     skuggan svagare (≤ 11 % alfa) och glasets minsta alfa 13 %.
   - *Settings-fönstret:* fönsterregeln hade `rounding = 0` → blur i hela rektangeln. Nu `rounding` = glasets radie
     (`material_radius`, tema × radiusScale), `rounding_power = 2`. **Hyprland tillåter max 20** i fönsterregler → Settings-glaset
     kapas också vid `glass.windowRadiusMax` (20) så formen är densamma.
   - Verifierat i nested (blur 90, radie 40, skugga 2): kantenergi innanför glaset 4,8 → 0,35 (blurrat), utanför hörn och i
     skuggzonen oförändrad (skarp); skärmdumpar av launcher, CC, OSD, notis och Settings.
   - *Incident:* production laddade om live mitt i arbetet (13:42) och `hypr apply` avbröts på `rounding 40 > 20`, före
     keybinds-avsnittet. Rättat samma minut med `bifrostctl hypr apply`; 74 binds verifierade, inga fel i loggen efter 13:42:30.
6. **Klock-popupen (#23) verifierad i nested** (skärmdumpar): media med en MPRIS-testspelare (`tools/dev/mpris-fixture.py`,
   körs på nested-sessionens D-Bus) – titel, artist, omslag, progress som tickar, paus → play-ikon, nästa → nytt spår;
   svenska med `BIFROST_LANG=sv` – nu även datum/veckodagar (`Time.localeName` låter `BIFROST_LANG` stå för systemspråket,
   som I18n; annars `clock.locale`/systemet); offline via `unshare -rn` (egen nätverksnamnrymd, ditt nät rörs inte) →
   "Väder otillgängligt: Offline"; vänster- och högerbar; knappen öppnar Settings på "Klocka & datum".
   Ej visuellt: offline *med* gammal data (`stale`) – bara logiken (selftest).
5. **Topbar-plattor** – de mörka plattorna var `bar.widgetStyle = boxed` (glasbubbla per widget). Befintlig inställning
   `integrated` ger platt normalläge med bakgrund bara vid hover/selected/pressed (`StateLayer`). Satt i användarens config
   (= standardvärdet, därför syns nyckeln inte i config.json). Ingen kodändring.

## 3. Config och migreringar (config-version **5**)
`shell/Core/Migrations.js` och `bifrostctl migrate()` implementerar samma steg. Båda måste ändras tillsammans.
- **1 → 2:** `appearance.variant` → `appearance.mode`. Ett felaktigt `appearance`-objekt på toppnivå i config.json tas bort.
- **2 → 3:**
  - `appearance.transparency.{bar,dock,windows}` → `materials.{bar,dock,menus,launcher,controlCenter,notifications,settings,osd}.transparency`
  - `appearance.glass.{grain,blur}` → `materials.all.*`
  - `borders.enabled`/`opacityScale` → `materials.all.border`/`borderOpacity`
  - `shadows.enabled=false` → `materials.all.shadow=0`
  - `bar.radius` → `materials.bar.radius`
  - `hyprland.blur.size` → `materials.blurStrength = (size-1)/0.39`
- **3 → 4:** `bar.style=islands` → floating + `background=none` + `widgetStyle=grouped`. `bar.systemStatus.appearance=boxed`
  → `widgetStyle=boxed`, och nyckeln tas bort.
- **4 → 5:** `materials.*.blur` bool → 0–100 (av → 0, på → `blurStrength` eller 20); `materials.all.blur` = `blurStrength`;
  `materials.blurStrength` tas bort. Ny nyckel `materials.link`.
- Borttagna nycklar: `materials.blurStrength`, `hyprland.keybinds`, `hyprland.blur.*`, `appearance.glass.*`, `appearance.transparency.*`,
  `appearance.borders.*`, `appearance.shadows.*`, `bar.radius` och `bar.systemStatus.appearance`.
- Nya nycklar:
  - `keybinds.*`, `appearance.{mode,syncSystem,density,location.latitude/longitude}`
  - `materials.*`
  - `bar.{background,widgetStyle,layout,frame.thickness}`
  - `hyprland.windows.{active,inactive}Transparency`
- Nya schemafält:
  - `template` (expanderas till inställningar), `page` (egen sida för en sektion) och `input: "field"` (nummerfält)
  - `nullLabel`, `inheritKey` (från mallen) och `dependsOnValue` (`{ key: value }`)
  - nullable bool
- Användarens config nu: materials med transparens (bar 47, dock 100, övriga 19) och `blurStrength` 49;
  `hyprland.manage=true`, `borderSize=8`; `keybinds.custom` och `workspaceStyle=moveFollow`; `widgetStyle=boxed` (från
  systemStatus); `openOnHover=false`; autohide på bar och dock.

## 4. Sökvägar i runtime
| Vad | Var |
|---|---|
| Installation | `~/.local/share/bifrost-shell` (just nu en symlänk till repot) |
| Kommandon | `~/.local/bin/bifrost-{ipc,settings,shell,terminal,screenshot}`, `bifrostctl` |
| Tjänst | `~/.config/systemd/user/bifrost.service`, `ExecStart=%h/.local/share/bifrost-shell/bin/bifrost-shell` |
| Shell IPC | `qs ipc -p ~/.local/share/bifrost-shell/shell call …` (eller `bifrost-ipc …`) |
| Settings IPC | `qs ipc -p ~/.local/share/bifrost-shell/shell/settings.qml call settings open|close|status|quit|search` |
| Genererad Hyprland-fil | `~/.config/bifrost/hypr/bifrost.lua` (hookad sist i `~/.config/hypr/hyprland.lua`) |
| Runtime-state | `$XDG_RUNTIME_DIR/bifrost/{applied,compositor,appearance}.json` |
| Ikoncache | `~/.cache/bifrost/icons/<tema>.json` |
| Backups | `~/.config/bifrost/backups/` (config.v*.json, system/ för främmande filer) |

Scratch-test utan att röra användarens config: en overlay-instans av repo-shellet med `BIFROST_CONFIG_DIR=<scratch>`.
Den körs bredvid production eftersom config-sökvägen skiljer sig. Lägg baren **nere**, eftersom produktionsbaren
(autohide) annars ligger överst i skärmdumpar. Använd aldrig `pkill -f` med ett mönster som finns i din egen kommandorad
(det dödade Claudes skal en gång).

## 5. Viktiga tekniska insikter (upptäck inte på nytt)
- Hyprland 0.56 Lua:
  - `hl.layer_rule()` och `hl.window_rule()` returnerar objekt med `:set_enabled(bool)`. Regler kan alltså ersättas live.
  - `hl.unbind(keys)` finns.
  - Fönsterregler har `no_blur`, `border_size`, `no_shadow`, `rounding`, `decorate`, `opacity` och fler (se `LuaBindingsInternal.hpp`).
  - `hyprctl eval` returnerar inget av `print()`; skriv till fil för att felsöka.
- Blurstyrka finns bara globalt i Hyprland, inte per layer. Refraktion av bakgrunden går inte (layer-ytor kan inte sampla).
- En layer-surface som är ankrad på alla fyra sidor kan inte reservera utrymme.
- `qs ipc` misslyckas tyst om funktionen inte finns. `qs list -p <entry> -j` ger pid.
- Quickshell cachar shaders per process: en shaderändring kräver omstart av shellet.
- Selftestet har vuxit och tar nu cirka 12–15 s. `selftest.sh` väntar upp till 40 s.
- Selftestets attrapper för glas måste ha `stripY`, `stripHeight` och `hole` (MenuHost läser dem).
- `ThemeLogic` får `(chain, variant, appearance, materials)`. Theme byggs om vid `appearance.*` och `materials.*`.
- `sed -i` på QML bryter Quickshells filbevakning. Använd Python/Edit (regeln i CLAUDE.md gäller fortfarande).
- `Region { item }` (Quickshell 0.3.1, `region.cpp`) = `mapToScene` av origo och bortre hörn → negativ storlek under
  rotation, och uppdateras bara av itemets egna x/y/w/h. Använd beräknade x/y/width/height (se `BarWindow.MaskRect`).
- Qt `Grid` positionerar direkt i `rows`/`columns`-setters: ett mellanläge rows=1/columns=1 ger varningen "more visible
  items than rows*columns". `BarRow.apply()` byter via 0/0.
- `XMLHttpRequest` fungerar i Quickshell för HTTP GET (ingen extern process behövs). Inline-komponenter (`component X:`)
  ser inte id:n i den omgivande filen – skicka värden som properties.
- Scratch-instans bredvid production: `BIFROST_CONFIG_DIR=<scratch> BIFROST_RUN_MODE=overlay setsid qs -p $PWD/shell &`,
  styr med `qs ipc --pid <pid> …` (entydigt), stoppa med `kill <pid>`. Den har egen dock som kan skymma nederkanten.

## 6. Tester som körts
- **Session 2026-09-25 kväll:** `scripts/selftest.sh` 336/336 (nytt: sidobarens menystorlek, `BarRow` staplar,
  `Metrics` för sidokant, klockmenyn kompilerar, Open-Meteo-parse, trasigt svar avvisas, väderikoner per WMO-kod);
  `tools/test_bifrostctl.py` 18/18; `bifrostctl validate` ok; production-loggen (`journalctl --user -u bifrost.service`)
  utan varningar efter live-omladdningarna. Visuellt i scratch-overlay: se #22 och #23 under FAS 5.
- `scripts/selftest.sh`: 327/327. Nya delar: migreringar, sol och theme mode, accentfamilj, material
  (tjocklek, kant, skugga, glöd, transparens), hover av/på, menyformer för frame, i18n-fallback.
- `tools/test_bifrostctl.py`: 18/18. Nya delar: keybinds utan dubbletter, custom och disabled, hypr-generering utan
  personliga sökvägar, fullständig svensk översättning.
- `Hyprland --verify-config` på genererad `bifrost.lua`: "config ok".
- Live i production: Settings-cykler, binds, CompositorSync, systemsynk av utseende, ikonbyte, blur per yta.
- Visuellt (skärmdumpar): Settings-sidor (engelska och svenska), density, ljust läge, färgväljare, dock-material,
  prisma, bar-kombinationer, menyer från bubbla och fristående, frame.

## 7. Kända problem och det som återstår att verifiera
- Glasshader och schema kräver omstart av production för att blurmask och Link ska synas där (fråga användaren).
- Klick i nested via `vpointer` fungerar sedan `f378287`; `hovertest.py` förutsätter att monitorstorleken inte ändras under körning
  (nested-fönstret byter storlek när värden tilar om).
- Riktiga tangenttryck (Super+Space, Super+T, volym och media) är inte provade av Claude. Användaren behöver testa.
- Hover med riktig mus inne i baren är inte verifierat.
- Frame är inte testat i nested/production (exklusiva zoner, blur och fullskärmsappar), inte heller sidobar där.
- Sidobar: reveal med riktig pekare, exklusiv zon i production och klockmenyn på sidobar är overifierade.
- Klockmenyn: `stale`-läget (offline med gammal data) och error-läget är inte visuellt verifierade.
- `MenuHost.screenRect`/AutoHide-arean antar att barfönstret börjar i skärmens hörn; en annan exklusiv zon på en
  intilliggande kant (t.ex. en annan bar uppe medan Bifrost är till vänster) förskjuter fönstret (sågs i scratch mot
  production-baren). Ofarligt i vanlig drift med en bar.
- Ljusstyrka: användaren har ingen backlight eller DDC, så bara OSD-förhandsvisning finns.
- `bar.systemStatus.clickCommand` är standard `kitty -e btop`, alltså hårdkodad terminal. Bör använda `bifrost-terminal -e btop`.
- `docs/ARCHITECTURE.md` beskriver fortfarande delvis den gamla glas-, transparens- och islands-modellen i §6, §10 och §10b.
  Avsnitten "Stabilisering 2026-09-25" nedan i ARCHITECTURE sammanfattar de nya systemen.
- Galleriets texter är svenska och inte översatta (galleriet är bara ett utvecklarverktyg).
- `ControlCenter.qml` räknar sin position i hörnet vid barens ände (`Metrics.panelInset`). #26 i FAS 6 flyttar den till docken.
- DMS `binds-user.lua` innehåller gester som anropar DMS IPC (pinch → DMS overview). De är ofarliga men döda.
  Användarens fil ändrades inte.

### Incident 2026-09-26 23:03: shellet borta efter ut-/inloggning (rättat)
- Hyprland kraschade vid utloggningen; `graphical-session.target` levde kvar, `bifrost.service` startades om utan
  compositor (Qt föll tillbaka till xcb och kraschade) och fastnade i `start-limit-hit`. Nästa inloggnings
  `start hyprland-session.target` var en no-op, så shellet startade aldrig.
- Rättat: `bin/bifrost-shell` avslutar med 0 om ingen levande compositor finns (socket + hållet `.lock`), och
  `bifrost.lua` (generatorn) kör vid `hyprland.start`: importera Wayland-miljön, `reset-failed`, `start bifrost.service`.
- Grundorsak: Hyprland 0.56.2/aquamarine 0.15.1 segfaultar i sin egen avslutning (`exit()` → `CDRMBackend` destruktor,
  även greeterns Hyprland). Uppströmsbugg, inte fixbar här. Ofarlig nu: Log out (production) kör `bin/bifrost-logout`
  via `systemd-run` (egen unit, utanför shellets cgroup) som stoppar `graphical-session.target` innan `hl.dsp.exit()`.
  Nested: vanlig dispatch som förut. Obs: `SUPER+SHIFT+E` i DMS `dms/binds.lua` laddas inte längre av hyprland.lua.

### Incident 2026-09-26 14:05 (läs!)
- **Lärdom:** skriv inte om QML med `str.index("            }\n")`-slicing – mönstret matchar inuti djupare indrag och
  lämnade en lös `}` två gånger (production behöll föregående version, men loggade fel). Använd exakta block + `assert count==1`.
- En test-hjälpare (`qskill "bifrost-shell/shell "`) matchade även production-shellets cmdline
  (`~/.local/share/bifrost-shell/shell`) och dödade det. systemd startade om `bifrost.service`; loggen efteråt är ren
  (inga QML-/Hyprland-fel; rounding-felet 40 > 20 från 13:42 är borta, `bifrost.lua` har rounding 20).
  **Döda nested/scratch-shell bara med mönstret `Projects/bifrost-shell/shell`** eller med pid.
- **(Rättat i `a10bdac`)** vid stoppet dödade systemd även `transmission-gtk` – appar som startas från shellet (launcher/dock)
  hamnar i `bifrost.service`-cgroupen och dör vid varje omstart. Bör åtgärdas (starta appar via
  `systemd-run --user --scope` / `app2unit`, eller `KillMode=process`). Inte gjort.
- Nested-Hyprlands fönster i värden försvann två gånger (output blir `FALLBACK` 0×0). En headless-output
  (`hyprctl output create headless`) inuti nested får ingen upplösning, så det går inte som osynlig testskärm.

## 8. Exakt var nästa session ska fortsätta
0. Läs CLAUDE.md → den här filen → ARCHITECTURE §13 → `git log --oneline`. Kör `scripts/selftest.sh` (ska ge 381/381).
   Fråga användaren om `systemctl --user restart bifrost.service` (behövs för glass.frag/blurmask och `materials.link` i production).
   Nested-hjälp: `scripts/vpointer.sh`, `tools/dev/hovertest.py` (se CLAUDE.md).
1. ~~Avsluta verifieringen av #23~~ (klar 2026-09-26, se ovan). Tidigare anteckning: i en scratch-overlay (se §4, sätt baren nere: `bifrostctl set bar.position bottom` mot
   scratch-`BIFROST_CONFIG_DIR`; starta med `BIFROST_CONFIG_DIR=… BIFROST_RUN_MODE=overlay setsid qs -p $PWD/shell`,
   styr med `qs ipc --pid <pid> call bar statusMenu clock`, stoppa med `kill <pid>`):
   - mediapanelen med en riktig spelare (t.ex. en video i webbläsaren eller `mpv`), progress och knappar;
   - offline-läget (t.ex. `clock.menu.weather` av/på, eller simulera genom att peka URL fel lokalt – committa inte det);
   - klockmenyn på vänster/höger bar; `BIFROST_LANG=sv` för svenska texter; Settings-knappen.
2. ~~#24~~ **workspace preview – klar (`8096d35`), verifierad av användaren i production 2026-09-26.** Hover på en workspace-pill öppnar en
   BarMenu med monitorn som karta (`Shared/WorkspaceMap.js`); fönster som levande bilder via `Compat/WindowCapture`
   (capability `windowCapture`, Hyprland) eller app-ikon. Inställningar `workspaces.preview`/`workspaces.previewLive`
   (båda default på). Fångst av fönster på dold workspace verifierad i nested via QML-logg (`hasContent true`).
   Production kör redan koden (se §7 om omstarten 14:05).
3. ~~#25~~ **VPN – implementerad (`cb11f63`).** `Services/Vpn.qml` följer `piactl monitor connectionstate` resp.
   `nmcli monitor` (LineWatcher) i stället för att bara polla när en meny är öppen; `Vpn.phase` = off/connecting/on.
   Ikonen: off = `textFaint`, connecting = pulserar (`textMuted`, bara om `Theme.motion.enabled`), on = `Theme.color.text`
   (nästan vit/svart; inga lägesspecifika värden i `_base`, så inte ren #FFF/#000). Monitorn verifierad i production
   (en `piactl monitor` per shell). **Inte verifierat:** ikonen vid faktisk på/av – kräver att användaren togglar VPN.
   Sidofynd, rättat (`edfedcd`): `LineWatcher` lämnade föräldralösa processer när `qs` avslutades utan destruktorer
   (varje selftest-körning → en `gsettings monitor`); nu `setpriv --pdeathsig TERM`. 16 gamla föräldralösa dödade.
4. ~~Frame-test (#22 slut)~~ **klart i nested 2026-09-26 (`38e2e75`).** Två fel hittade och rättade:
   - Frame-fönstret hade `exclusiveZone: 0` och placerades därför *innanför* FrameReserve-zonerna (ramen 10/34 px
     för långt in, oblurrad tapet vid kanten). Nu `-1` i frame-läge. Syntes inte i overlay (där finns inga reserver).
   - Vänsterbar: pekaren på x = 0 träffar det vridna bandets exklusiva bortre kant → ingen reveal. Nu en 2 px
     `edgeCatch`-MouseArea förbi kanten. (`containmentMask` med QML-`contains()` fungerar inte för hover – prövat.)
   - Verifierat: frame topp/botten/vänster/höger (reserved-zoner, blur under ramglaset, fullskärm täcker ramen),
     autohide-reveal på alla fyra kanter. Känt: bottenbar + dock – mitt på nederkanten får docken pekaren
     (samma på HEAD före ändringen); utanför docken fungerar reveal.
   - **Inte testat i production** (användarens `bar.layout = bar`).
5. **Appar överlever omstart (`a10bdac`):** `Platform.launch()` (appar, xdg-open, klickkommandon) kör via
   `systemd-run --user --scope --slice=app.slice --unit=app-bifrost-<id>-<rand>` när `INVOCATION_ID` finns.
   Verifierat i nested med `INVOCATION_ID` satt (dockstart → egen scope). Appar som startades *före* ändringen ligger
   kvar i `bifrost.service` och dör vid nästa omstart. `Platform.execDetached` är kvar för shellets egna hjälpare.
6. Kör selftest + `tools/test_bifrostctl.py` + `bifrostctl validate`, uppdatera HANDOFF, commit, sedan FAS 6.

### Session 2026-09-25 kväll: ändrade filer
- #22: `schema/bar.json`, `i18n/sv.json`, `shell/Core/Metrics.qml`, `shell/Modules/Bar/{Bar,BarMenu,BarWindow,BarZone,MenuHost,WidgetHost}.qml`,
  `shell/Modules/Bar/Widgets/*Widget.qml` (alla utom Status-/Tray-menyer), `Widgets/BarButton.qml`, ny `Widgets/BarRow.qml`,
  `shell/Modules/ControlCenter/ControlCenter.qml`, `shell/Modules/Notifications/{NotificationCenter,NotificationPopups}.qml`, `shell/selftest.qml`.
- #23: nya `shell/Services/Weather.qml`, `shell/Shared/MonthCalendar.qml`, `shell/Modules/Bar/Widgets/ClockMenu.qml`,
  `assets/icons/cloud*.svg`; ändrade `Widgets/ClockWidget.qml`, `Widgets/BarButton.qml` (`spacing`), `Services/Media.qml`,
  `Modules/ModulesIpc.qml` (kommentar), `schema/clock.json`, `themes/_base.json` (`layout.clockMenuWidth`), `i18n/sv.json`, `shell/selftest.qml`.
- Docs: `docs/HANDOFF.md`, `docs/ARCHITECTURE.md` (§13), `docs/EXTERNAL-APIS.md` (Nätverk: Open-Meteo, MPRIS position).

### Senaste commits
- `e5225ce` Workspace preview: real wallpaper, stable live pictures
- `582f392` Bar: no flicker when menus open and close
- `6e5f9b7` Notification center is the bell's bar menu
- `ef889df` Launcher placement: Dock (default), Center, Top panel (#27)
- `9588299` Control center grows out of the top panel; placement system (#26)
- `a10bdac` Apps outlive the shell: each launch in its own systemd scope
- `38e2e75` Bar: frame covers its own reserved space; side-bar reveal at the very edge
- `cb11f63` Bar: VPN icon follows the connection live (#25)
- `edfedcd` LineWatcher: child dies with the shell
- `8096d35` Bar: workspace preview on hover (#24)
- `f378287` Materials: blur amount per surface, Link all surfaces, blur follows rounded glass
- `253b1a8` Popups: switch at once along the bar; virtual-pointer hover test
- `d342162` Popups: panels no longer block hover-switching on the bar
- `8597ae6` Bar: clock menu with calendar, weather and media (#23)
- `1e06c41` Bar: left and right positions (#22)
- `3e14dc1` HANDOFF: stabilisation phases 1–4 and the frame part of phase 5
- `b90310e` Bar: frame layout (top/bottom)
- `1d87c04` Phase 4: one hover setting for every bar menu

## 8a. FAS 6 (2026-09-26): placeringssystemet, CC och launcher
- **Användarens beslut:** Control Center ska växa ur **topbaren** (inte docken). `controlCenter.placement` = Top panel
  (`bar`, standard) | Dock. Launcher: `launcher.placement` = Dock (standard) | Center | Top panel.
- **`Modules/Placement.qml`** (singleton): `resolve()` (dock → fallback utan dock/dockobjekt), `placeFor(panel, requested,
  fallback, screen)` (Top panel kräver panelens knapp på den skärmens bar = *bar host*), `registerBarHost()`,
  `dockPanel` (en panel i taget på docken; `showOnDock({id, screen, component, close, exclusiveKeyboard})`).
- **Top panel = en riktig BarMenu** i knappens widget (`ControlCenterWidget`, `LauncherWidget`): växer ur baren via
  MenuHost (samma glas, hover-byte, leave/utanför-klick). Menyn och `ShellState.*Open` speglar varandra, så IPC/tangenter
  öppnar samma meny. BarMenu-egenskapen `panel` ("controlCenter"/"launcher") gör att ShellState inte stänger panelen när
  dess egen meny öppnas. Utan knapp på skärmen: CC:s eget fönster vid baren, launcher i mitten.
- **Dock:** `Dock/DockPanelHost.qml` ritar panelen som en del av dockglaset (`Shared/GlassJoin.js`, utbruten ur MenuHost,
  samma formtester). IPC `dock status` ger hover-läget. Dockfönstret växer uppåt; glasets autohide-offset animeras separat.
- Innehåll delat mellan lägena: `ControlCenterContent.qml`, `LauncherContent.qml` (egen `prepare()` vid varje öppning,
  `maxHeight` från värden). `BarMenu.exclusiveKeyboard` / dock-begäran `exclusiveKeyboard` → Exclusive tangentbord.
- **Verifierat i nested:** CC ur topbaren (skärmdump; klick, leave, utanför-klick, IPC), `hovertest.py` 42/42 och
  `--via-popup` (ett tillfälligt fel som inte återkom i 3 körningar), CC ur docken (skärmdump, leave), launcher Top panel
  och fallback (via IPC-status), övriga paneler (launcher center, notiscenter, OSD, strömmeny: skärmdumpar).
- **Inte verifierat visuellt:** launcher i Dock- och Top panel-läge (nested låg på en annan workspace än användarens).
- **Production:** schemat läses bara vid start. Efter `systemctl --user restart bifrost.service` öppnas launchern ur
  **docken** (standard) och CC ur topbaren. Fråga användaren före omstart.

### Efter FAS 6 (2026-09-26 ~15:50): notispanel och flimmer
- **Notiscentret är klockikonens barmeny** (`6e5f9b7`), som CC: växer ur baren, barens material; eget fönster bara om
  baren saknar klocka. `Modules/Bar/PanelMenu.qml` = BarMenu som är värd för en skalpanel och följer dess ShellState-flagga
  (används av CC, launcher, notiser).
- **Flimmer i baren** (`582f392`): varje storleksändring av barfönstret visar *en bildruta utan glas* (Qt/Wayland). Förr
  växte/krympte fönstret vid varje menyöppning/stängning. Nu reserverar `MenuHost.standingRoom` (90 % av skärmen) plats
  från start; dockan likaså när en panel är placerad där (`Placement.dockHostsPanels`). Mätt i nested med användarens
  config (kopia i scratch): 21 → 0 blinkningar på 30 cykler. Mätverktyg: grim-bildrutor av barremsan + ljusstyrkeanalys
  (se sessionens `flashtest.sh`-idé: öppna/stäng via IPC, räkna enstaka bildrutor som avviker >2 från båda grannar).
  **Regel:** ändra aldrig storlek på bar-/dockfönstret under användning.
- AutoHide: ett okänt `pointerIn`-svar (null) räknas som "inuti" (gömmer inte).
- **Singletons byggs inte om vid live-reload.** Ny egenskap/funktion i en singleton (t.ex. `Placement`) kräver omstart av
  production, annars TypeError (hände: `placeFor` → launchern öppnades inte förrän omstart 15:40).
- Testfel i nested kan bero på att användarens riktiga mus rör sig över nested-fönstret (samma pekare).

### Workspace preview: wallpaper och stabilitet (`e5225ce`, 2026-09-26 ~16:05)
- `Services/Wallpapers.qml` = enda källan för vilket wallpaper en skärm visar (`sourceFor(screen)`, `fillMode`), används av
  `Modules/Wallpaper` och previewn. Per-skärm-wallpaper finns inte i schemat; ändras bara i `sourceFor()`.
- Previewns rutor: `ListModel` synkad per fönster-id (`WorkspaceMap.sync`), för **alla** fönster på monitorn (andra
  workspaces dolda) → inga ombyggen vid geometri-poll eller workspace-byte. `WindowCapture` behåller källan när dold.
  Ikon bara om ingen bild kommit inom en grace-period, aldrig efter att en bild kommit.
- Mätt i nested (bildrutor + ljusstyrka per ruta): 0 blinkningar (10 s hover, in/ut, ws 2↔1). Wallpaperbyte slår igenom
  direkt; `previewLive=false` ger ikoner på wallpaper. **Tom workspace inte skärmdumpad** (nested dolt på annan workspace).
- Tips: Item-egenskaper (`z`, `x` …) som ListModel-roller → "Cannot override FINAL property"; döp om rollen.

### Control Center: ljudenheter och Wi-Fi (2026-09-26 ~16:30)
- `Services/Audio`: sinks+sources, `setSink/setSource` (Pipewire.preferredDefault* = systemets riktiga default),
  `kindOf/iconOf`, mute per enhet, BT-profiler via `pactl` (`btCards`, `profileChoices` = Musik / Headset + mikrofon).
- `Services/NetworkStatus`: `networks` (sorterad), skanning bara när listan visas, `connectTo/connectWithPassword/
  disconnectFrom/forget`, fel per nätverk (`connectionFailed`), `pending`, `internet` (NM connectivity).
- UI: `Shared/AudioDevices.qml`, `Shared/WifiNetworks.qml` (lösenord inline i raden). CC: nätverksbrickan → Wi-Fi,
  volymreglagets enhetsnamn → utgångar, mikrofonbrickan/-reglaget → ingångar (`CCSlider.expandable`).
- **Verifierat live (nested, riktig PipeWire):** byte av utgång HDMI↔AirPods och ingång analog↔AirPods-mic (wpctl
  bekräftar), extern `wpctl set-default` syns direkt i CC, profilbyte via CC lade till AirPods-mic i listan. Återställt.
- **Inte verifierat:** Wi-Fi live (radion var av, inga sparade nätverk; att ansluta kräver användarens nätverk/lösenord),
  fysisk in/urkoppling av enhet (profilbytet testade samma lista-uppdatering).
- **Production måste startas om** (`Audio`/`NetworkStatus` är ändrade singletons) innan listorna öppnas där.
- Varning för tester: varje ny vpointer-process stänger CC (enhet försvinner = leave); gör allt i EN pekarsession och
  kontrollera layout med skärmdump före klick (ett felklick satte energiprofilen till Prestanda; återställd).

## 9. Återstår av originalplanen
- **FAS 5:** #24, #25, verifiering av #23 (media/offline/sidobar), frame-test i nested/production.
- **FAS 6: klar i kod 2026-09-26** (`9588299`, `ef889df`), se §8a. Visuell kontroll av launcherns tre lägen återstår.
- **FAS 7:**
  - #28 och #29 är i praktiken klara (se FAS 1). Verifiera med riktiga tangenter.
  - #30 kvar: skärmdumpar finns, mediatangenter finns, `micMute` och `stop` har lagts till.
  - #31 OSD för mute, mic, media-feedback och materialinställningar. Material per OSD finns via Glass & materials (yta osd),
    men OSD för media och mic saknar egen design (`mic` visas med mikrofonikon).
- **FAS 8:** ~~#32~~ klar 2026-09-26 (`6e7e9a1`, parningsagent; se §0),
  #33 Display med capability-detektering per skärm (HDR, 10-bit, färgprofiler; `DisplayPage.qml` finns).
- **FAS 9:** #34 SDDM-tema (`sddm/install-sddm.sh` förväntas av `install.sh`).
- **FAS 10:** #35 clean install (en riktig kopia i stället för `--link`, installera SDDM, testa med en ny användare),
  #36 sluttest av hela listan.

---

## Äldre historik
Fas 0–8 i det ursprungliga bygget: se `git log` före `cc8ceff` och tidigare versioner av den här filen
(`git show 1d38c34:docs/HANDOFF.md`). Standardglaset som godkändes 2026-09-24 ligger fortfarande i `themes/_base.json`.
Alla materialinställningar är tomma som standard, vilket betyder exakt det godkända utseendet.

## Current continuation — 2026-09-26 (Codex)

Start with `docs/CURRENT-STATE-AUDIT.md`, not historical phase numbers above.
Baseline is a065e83, selftest 381/381, CLI 21/21, validate OK.
Topbar input geometry: `bandHeight` previously included Theme.space.xs beyond
its reserved area. Removed that interactive extension for all four edges,
including frame and revealed autohide. Shadow/menu window room remains separate.
This fixes a concrete client-edge overlap; real Vivaldi acceptance remains unverified.

Settings layout: SettingRow now measures intrinsic editor width and stacks below
text when narrow; descriptions/notes wrap. BSegmented wraps options; color editor
rows use Flow. 405/405 selftests (24 geometry cases at 320/520/800/1400), CLI 21/21.
Visual font-scale and custom-page layout acceptance is still pending.

FullBlue is now the implicit default in both modes. No config migration rewrites
explicit icon choices: missing/null already means the implicit default, and reset
removes the override. scripts/install-icons.py installs the bundled editable SVG
snapshot offline, checks its hash and builds the cache. See assets/icon-theme/README.md.

Battery: Power now exposes UPower aggregate state via native signals;
BatteryWidget supports percentage, charge levels, charging and a status popup.
No default widget insertion. On battery-less machines it stays hidden and the
Add widget entry is disabled. Hardware laptop acceptance remains pending.

Media: topbar widget uses existing Media service; manual selection is by MPRIS
bus name and falls back when the player disappears. Clock and widget reuse the
same Shared/MediaPanel (artwork, metadata, transport and supported progress).
Selftest: 409/409; CLI: 22/22; config validates. Live MPRIS switching remains to test.

App actions: DockMenu now hosts Shared/AppMenuContent; Launcher right-click uses
that same content in an in-window GlassSurface popup, preserving the launcher's
focus grab. Pin/unpin is read from dock.pinned live. Open/new window, app metadata,
window selection and close actions are shared. Escape/outside click close the
launcher popup. Interactive nested acceptance is pending: nested Hyprland cannot
initialize its Wayland backend in this sandbox (CBackend::create failed).

Frame: outer material radius is now zero (also used by attached menu geometry),
inner radius is Theme.windowRadius, shared with the compositor generator's
explicit-or-theme rounding. Theme-defined radii now also reach compositor config.
Decorative frame sides no longer take pointer input. Existing material controls
remain the frame styling source; no second material/radius settings engine added.

Theme browser: Tinted Theming chosen after comparing upstream catalogs (351
validated Base16 themes vs 44 DMS registry entries). Integrated under Appearance
and the Theme editor. CLI supports browse/refresh/install/update/remove; JSON-only
palette conversion extends _base, preserving Bifrost materials and icons. Native
user-theme file watching supports live updates. See docs/THEME-CATALOG.md.

Brightness: one service now discovers all backlights and DDC displays; shared
BrightnessControls is used in Control Center and Displays. DDC writes target an
explicit I2C bus and use the reported VCP maximum. Writes are serialized/coalesced;
failures display an error and read back state. External values refresh every 10 s
only while a consumer is visible. No-device probe returned an empty list here.
Hardware success and hotplug acceptance remain pending. CLI regression includes
multi-display identity, non-100 maximum and failed writes.

## Network management and approved preview polish (2026-09-26)

NetworkPage extends NetworkStatus with nmcli profiles, interface details, saved Wi-Fi/Ethernet/VPN actions and IP/DNS/routes/proxy editing. VPN consumes this shared profile state. CC has a Network settings shortcut. Hidden WPA-personal/open SSIDs use NetworkManager D-Bus with JSON over stdin (optional python-gobject); enterprise creation uses nm-connection-editor when available. No live connection was changed during testing. Profile fetches ignore stale responses.

User approved restrained workspace polish: stronger active border, quieter labels and spacing. Capture, wallpaper and mapping remain unchanged.

## Final checkpoint 2026-09-26

436/436 selftests, 26 CLI tests, validate and installed-copy validate pass. Empty HOME install and reinstall in /tmp/bifrost-clean succeed, including bundled FullBlue/cache. Required doctor dependencies pass; optional NVIDIA driver warning. Production journal shows successful automatic reloads; no manual production restart. Mesa Zink warning is test-environment noise. Nested Wayland backend failed to start, so no Vivaldi hover matrix or separate-SSD/reboot acceptance claim.

Read SETTINGS-AUDIT-2026-09-26.md: all 233 schema entries listed, missing Input/full keybind editor/idle and proposed Advanced organization are explicit. User approval requested before larger Settings changes. DisplayPage custom row now wraps/stacks; unused frame input items removed. Tinted archive expansion is bounded. Continue from these results without repeating finished implementation; prioritize accepted audit scope and remaining hardware tests.

## User acceptance and corrections

User confirms Vivaldi works; close that item. User reports missing CC brightness and launcher centered despite Top panel. Actual config selects bar but contains no launcher widget: Launcher now preserves explicit bar placement and uses Metrics panel edge when no host exists, retaining button-hosted menus when available. Brightness shared UI now shows detection/no-device status and retry instead of disappearing. DDC discovery retains valid displays on partial nonzero detection exits and accepts indentation. Sandbox /dev has no I2C devices, while host DDC cache contains i2c-5; sandbox discovery must not be treated as host hardware acceptance. Physical brightness control remains unverified.

### Joined launcher placement correction
User clarified panel placement must grow from the actual panel, not float beside its edge. BarWindow now supplies a PanelMenu anchor when no launcher widget is configured. It uses existing MenuHost/GlassJoin and the panel's material/geometry. The standalone launcher is only used for center placement. Dock retains its DockPanelHost/GlassJoin path. Hidden launcher content no longer steals search focus. Bar and dock use OnDemand plus their existing compositor focus grab: combining Exclusive with the grab immediately dismissed the launcher on the current Hyprland session. Verified production panel open via IPC, bar status and screenshot; closed after checking. Dock code uses the same corrected focus arrangement; separate interactive dock acceptance remains.

## Dock edges, frame integration and free position
Dock settings now expose bottom/top/left/right/free and normalized freeX/freeY. Drag the handle in free mode; saved position scales with screen size. Free mode stays visible and reserves no workarea; edge modes reserve via FrameReserve and retain autohide. Frame dock and its open panel are extra joins of the frame shader, not doubled translucent surfaces. DockPanelHost uses the selected edge for placement and joins. Added pure geometry checks for every edge and out-of-bounds free coordinates. Scratch overlay verified bottom/frame and left/frame with launcher visually; top/right/free verified through dock IPC geometry. No host workspace/window dispatches used. Shader binary rebuilt.

## Follow-up Settings and dock features

- Dock: optional launcher entry and index (0 = first), preserved separately from desktop-id pins. Window previews reuse Compat.WindowCapture/Compositor.captureSource; up to four app windows, title fallback and click-to-focus. Tooltip positioning supports all four dock edges. Pointer transition keeps previews open while inside. Hardware screencopy still depends on compositor support.
- Weather: Clock & date has a Weather location editor. Search city/postcode via Open-Meteo geocoding, select an explicit result; the saved name/coordinates survive restart. Empty object restores ThemeMode/time-zone location. Changing place aborts a stale forecast request. Online Stockholm lookup verified.
- Settings mouse-wheel step is now three large control rows per notch across schema/custom pages; precision touchpad deltas keep native handling.
- Shadows: layer blur-mask threshold now scales with shadow strength (matching JS/Python) so deep shadows are not capped to the standard alpha. Material preview inside Settings no longer incorrectly uses a layer-surface blur mask. The frame no longer hardcodes elevation to zero: its inward shadow and joined dock now follow the bar material. Pixels beyond the physical screen remain clipped.
- Themes & colours: nullable appearance.foreground.light/dark set text and monochrome icons, including top-panel icons. Semantic status colours and app artwork retain their roles. Light mode faint text and default icon contrast improved.

Final regression: 456 QML tests and 28 CLI tests pass, including preview-click cleanup. Shader/runtime changes should be checked after a fresh Settings/shell start. The actual session hot-reloaded successfully, but no full production restart was performed. Vivaldi is explicitly user-confirmed working and is closed, not pending.

### Dock preview eligibility fix
Hover no longer opens an empty/name-only popup for pinned apps without windows or the launcher entry. Opening is gated both before the hover timer starts and when it fires. Closing the last window, or disabling previews, stops pending timers and closes any existing preview immediately.

### Dock preview lifetime across window polls
The compositor refreshes windows every ~700 ms. Dock's array-backed Repeater recreated app delegates on each refresh, destroying their hover popups. DockModel.syncKeys now updates a stable ListModel by entry key, moving/inserting/removing only changed entries. Preview window delegates likewise persist by window id. BPopup exposes hover over the full glass including padding; DockItem keeps the preview open over either the app or popup, with a short transfer delay. Regression checks ensure repeated polls and reorder preserve delegate identity and remove only closed entries.

Dock autohide now also stays pinned while any app preview is visible. Moving the pointer from an app into its preview therefore keeps the dock and popup anchor in place; leaving both closes the preview and releases the normal autohide delay.

### Dock preview input mask follow-up
The user still observed premature closure after the stable-model/autohide fix. BPopup now offers opt-in bodyInputOnly, enabled by dock previews: only the glass body accepts input, so transparent shadow padding overlapping the app cannot take the pointer from the app while also reporting no popup hover. Other popups retain their full input region. Production reloaded without QML warnings; 459 selftests and 28 CLI tests pass; validate/doctor run. Interactive nested reproduction could not start because the sandbox GPU backend failed; actual pointer behavior remains unverified.

### Dock preview confirmed fix: shared dock surface
User reproduction with temporary event logs confirmed closeTimer fired with both native-popup and icon hover false. Stable delegates and the popup shadow mask alone were insufficient. Replaced DockItem's BPopup with one DockPreview Item per screen, rendered within the existing full-screen dock surface and added to its input mask. AutoHide pins directly to the preview host. LeaveWatch checks the app, preview and connecting gap against compositor cursor coordinates before closing. Live captures retain their stable window model; long lists scroll within the screen. Removed temporary logs and the now-unused BPopup hover/mask additions. The user explicitly confirmed both preview and dock remain open when moving into the preview. Selftests cover ownership, refreshed window data and closure/blocked opening for stopped apps.

## Input Settings
Added Input hub with Keyboard, Mouse, Trackpad subpages using existing controls. Central InputDevices service delegates discovery to Compositor/HyprlandBackend and edits schema-backed input.devices/gestures/activeLayouts. No parallel application backend: existing CompositorSync + bifrostctl generator persists/applies changes. Per-device field snapshots support live reset; XKB options preserve unrelated options, layout catalog/variants come from system XKB XML, active layout selection is persisted, keyboard test field and device selectors included. Trackpad gestures expose supported 3/4-finger directions and compositor or Bifrost panel actions, resolving overlapping swipe slots. Existing Lua callbacks are shown as custom; see EXTERNAL-APIS limitation on restoring opaque callbacks. Actual Glorious mouse and Apple Magic Trackpad classified using udev/kernel data; no raw input events read. Full libinput queries are optional when device access is permitted. Unsupported/no-device states hide controls. Production UI was visually reviewed and no input preferences were changed by the agent during verification (user independently set trackpad scroll_factor=1).

## 2026-09-26 — dock order, joined materials and bar foreground
- Dock left-drag now chooses an insertion point and commits persistent `dock.order` on release; launcher index follows drops. Running apps are not auto-pinned. Stable delegates remain during the drag; previews close and autohide stays revealed. All edge orientations use mapped coordinates. No host pointer injection was used.
- Frame glass now resolves its dock attachments with `Theme.materials.dock`, while retaining one distance field to avoid doubled transparent seams. All-surfaces linking reaches joined dock material; shaders rebuilt.
- Clock date/week use primary foreground; CPU/RAM/GPU icons match their text, including warning state.
- Validation: 479 QML checks, 32 CLI tests, validate and required doctor dependencies passed. Interactive drag and physical gesture testing still require the user session.
- Next: standalone Mission Control-style overview, research native capture/gesture/workspace animation first. Keep Super+Tab untouched.

### Dock follow-up
User clarified frame-attached dock must retain the frame tint: joined dock fill now uses frame tint with dock opacity. Dock menus now expand the parent input mask while open and dismiss on outside press; popup shadow is excluded from input. User confirmed outside click closes it. Selftest 479/32 still passes.

## 2026-09-26 — window overview and final dock/scroll refinements
- New standalone `Modules/Overview`: Super+O / `overview open|close|toggle` IPC, live proportional nonoverlapping tiles with app icon/title, workspace strip (active outline, filter by click, next empty workspace drop target), one overlay per output. Click focuses a window via facade then closes; Escape closes without focus dispatch. Drag targets any workspace in the strip; silent backend move keeps overview open. Stable tile identities retain capture sources across geometry polls.
- Hyprland owns native horizontal workspace motion. Generated config sets slide on workspaces/In/Out with ease-in-out; duration exposed in Workspaces. Existing four-finger pinchout→open, pinchin→close replaced by Bifrost callbacks through input.gestures, four-horizontal workspace retained. Existing 3-finger settings preserved. Super+Tab / Super+Shift+Tab native binds checked read-only, unchanged. User confirmed Super+O and native workspace swipe/reversal work. Open/close IPC additionally confirmed focused window unchanged.
- Native macOS differences and verified sources in EXTERNAL-APIS. Screenshot reviewed on 5120×1440 with portrait/landscape windows and live video. Multi-output implemented, only one physical display available. Window move/focus dispatches not injected on host; physical drag-to-workspace not independently exercised.
- Dock Settings: extra padding enlarges dock independently of icons; optional Trash and Overview buttons, existing Launcher option retained. Specials share app magnification/lift/highlight/name-delay behavior. Hover settings include scale, inward lift, background, app labels, delay. Trash opens trash:/// via installed xdg-open (no deletion actions). All buttons draggable.
- User clarified attached dock is literally part of frame: removed regional material machinery from the earlier intermediate commit. Attached dock uses the exact frame material/radius and its glass join tracks the animated dock rectangle, growing from the chosen frame edge during reveal instead of popping in/out. Standalone dock retains dock material. With All-surfaces linking, both resolve linked settings.
- Normal monochrome bar widget icons match primary text; warnings and disabled/busy states retain semantics. CPU/GPU/date/week/time already unified.
- Settings wheel now smoothly accumulates destinations and reverses immediately; touchpad pixel scrolling stays native. Approximate browser-style scrolling, not Vivaldi's private implementation.
- Validation: 489 QML checks and 32 CLI tests passed, config validation and required doctor dependencies passed. Existing sandbox Mesa warning and doctor symlink false negative unchanged. No agents used.

## 2026-09-26 — confirmed frame rendering and Settings pointer scrolling
- Root cause of transparent dock identified with live geometry and cropped screenshots: frame's material was opaque and join geometry correct, but the running Qt shader cache retained an earlier incompatible shader at the same URL. Renamed the shader source/bundle to `glass-frame.frag(.qsb)` and updated GlassSurface URL, forcing fresh shader loading on QML reload. Verified screenshot now shows an opaque dock joined to the frame. Attempted systemd restart was unavailable from sandbox D-Bus; no restart was needed after unique asset URL. Temporary diagnostic IPC and forced-reveal property removed.
- `DockGeometry.frameExtension` clips the animated dock rectangle to its protrusion beyond the frame, so the joined glass continuously shrinks/grows during autohide (the old join helper ignores normal-axis offsets). Regression checks for bottom/left/hidden state.
- Settings scrolling: explicit immediate pixel-delta handling plus separate TouchPad handler, preserving platform momentum events. Previously accepting the event in WheelHandler then declining it did not deliver usable scrolling to Flickable. Mouse notch smoothing stays separate. User confirmed right-side trackpad scrolling and dock appearance both correct.
- Settings scroll indicators are now interactive: broad fixed pointer target, thumb widens on hover/press, pointer dragging maps through the viewport scroll range, and grabbing stops pending mouse-wheel animation. Other users of BScrollIndicator remain passive by default.
- Validation: 492 QML checks + 32 CLI tests pass; live logs clean. No host pointer injection.

## 2026-09-26 — launcher clicks, clock weather, media and window borders
- Dock hover names no longer use native PopupWindow/BPopup. They render in a shared noninteractive GlassSurface on the dock, outside its input mask. This removes an intervening native popup from the click path. User confirmed launcher now opens on the first click, including after hovering its name. Temporary event/stack logs removed.
- Clock weather row/column and text have explicit width constraints; long conditions/locations wrap within the left column, forecast uses Flow. Screenshot verified the long Norrahammar/Jönköping location no longer reaches the calendar.
- Shared MediaPanel now contains player selection when multiple MPRIS players are available, including the clock panel. The standalone MediaWidget uses that same selector instead of duplicating it.
- Existing mpv did not publish MPRIS (playerctl listed only Vivaldi). Built hoyon/mpv-mpris source commit de552ae185399073b4fbc8557fa64c9543cdcf9f and tested metadata title plus pause in an isolated dbus-run-session with a generated silent WAV and --vo=null --ao=null. With granted filesystem permission, installed mpris.so in ~/.config/mpv/scripts; no system package/config modification. Loads on next mpv start; existing user's movie left playing. Plugin is a local app integration, not a Bifrost runtime dependency. Build source was /tmp/bifrost-mpv-mpris.
- Windows & compositor → Border & corners now has nullable active/inactive window border colour controls (hyprland.activeBorderColor / inactiveBorderColor). Defaults follow theme/accent. Generator applies only through the existing manage block; no shell-surface colours changed. Overrides and reset-to-theme tested.
- Validation: 492 QML checks, 33 CLI tests, validate and required doctor dependencies pass. Working shell logs clean.

### Frame dock artwork clipping (2026-09-26)
User requested icons disappear at the frame inner edge during autohide, not at the physical screen edge. Dock glass/artwork now lives inside a clipped viewport bounded by frame insets. A counter-offset content item preserves existing screen-local geometry for joins, drag/drop, popup anchors and previews. Only frame-attached dock is clipped; detached/free dock remains unchanged. Frame glass itself still owns the joined shape. Validation: 492 QML / 33 CLI tests, validate, required doctor checks pass; live reload log clean.

### Dock special-button icon theme (2026-09-26)
Overview, Trash and Launcher now resolve standard icon-theme names through Platform.iconPath/IconLookup, sharing the normal artwork Image and hover effects. Built-in glyphs remain an image-error fallback. Current selected Gruvbox theme contains all three icons. Validation: 492 QML / 33 CLI checks, validate and required doctor dependencies passed; live reload log clean.

### Global shadows (2026-09-26)
All surfaces → Shadow now also generates Hyprland decoration.shadow enabled/range inside the existing hyprland.manage guard. Zero disables compositor window shadows; positive values scale the native default 4px range. Per-surface overrides do not change window shadows. Description explicitly excludes app-drawn shadows. Shadow material fields have hyprland scope (also needed for blur masks); central sync explicitly includes the global key for already resident schemas. Applied existing user value 0 through bifrostctl hypr apply; read-only hyprctl confirmed enabled=false. 492 QML and 34 CLI tests pass, including zero/positive/local override/manage-off cases.

### XWayland context-menu blur artifact (2026-09-26)
The large rounded grey surround on ChatGPT's context menu was background blur on the transparent menu margins, not compositor shadows. Live screenshot with shadows disabled showed the artifact. A Chatgpt-class rule did not affect it: X11 inspection found an unnamed menu with no WM_CLASS. A no_blur rule matching empty class AND empty title AND XWayland AND floating removed the surround immediately in a screenshot of the same open menu. Final generated rule uses bifrost-xwayland-menu-blur, only while hyprland.manage is enabled, with explicit removal when disabled. Initial diagnostic rule removed from runtime. Normal named app windows and Bifrost glass remain unaffected. App-rendered subtle menu shadows remain outside Bifrost's shadow control. Validation: 492 QML / 35 CLI tests, validate, hypr verify/apply and required doctor dependencies pass. No input injection or window/workspace dispatches.

### Shadow range visibility (2026-09-26)
User still found Shadow ineffective. Screenshot comparison at 0 and 3 confirmed the frame shadow was responding but remained very narrow/subtle; original compositor mapping only reached 12px and retained host render_power=5 and fixed alpha. Global window shadow now scales both range and opacity from base mid-elevation tokens (3 = 60px, 72% alpha), theme void colour, consistent falloff for active/inactive windows. Shell shadow preserves standard value 1 but increases high-value blur quadratically and opacity with power 1.5. Zero remains off. Live screenshot reviewed, host range/colour verified; user's current value 3 retained after temporary 0 comparison. 492 QML / 35 CLI tests, validate, hypr verify/apply and doctor required checks pass.

### VRR-only display changes (2026-09-26)
Confirmed saved DP-2 VRR=false while hyprctl reported true after repeated applies. Hyprland 0.56.2 MonitorRule::compare omits VRR, and refresh processing calls ensureVRR before the scheduled monitor rule update. Added shared Compat/MonitorApply.lua used by runtime backend and embedded in generated config: reapplies once after 250ms, cancelling superseded per-output timers. Runtime/generator use +/-0.01Hz mode-selector bias keyed to VRR to force rule comparison mismatch while selecting the same advertised mode (1Hz matching tolerance). Saved refresh stays unchanged. Live test verified on→true and off→false after 800ms, both retaining 5120x1440@239.761. Restored saved off. Validation: 494 QML / 37 CLI tests, validate, hypr verify/apply and required doctor checks passed. Other concurrent Bluetooth/material changes were left untouched.

### Gesture labels and Settings scroll speed (2026-09-26)
Swapped the two pinch display labels as requested by the user; underlying gesture keys and existing actions remain intact. Settings precision/trackpad scrolling now scales deltas by 1.8; mouse wheel advances three large rows per notch instead of two, with fast (100ms base) rather than normal (180ms) easing. Values live in control.settingsScroll theme tokens. Momentum, clamping, direction reversal and direct trackpad handling retained. Settings hot reload clean; 497 QML / 38 CLI checks, validate and doctor required checks pass. Concurrent Bluetooth/prompt changes left untouched.

### Dock menu clicks and app actions (2026-09-26)
User reported all native dock context-menu actions unresponsive, not just Kitty. Moved DockMenu onto the dock layer Item surface (z above fullscreen outside-dismiss area), with geometry clamping, padding input consumption, Escape and compositor focus grab. User confirmed menu buttons work and Kitty opens a new window. Menu uses frame/bar material when frame-attached, matching frame menus; otherwise schema-linked popover material. Apps.newWindowAction prefers explicit desktop new-window action (Vivaldi/Nautilus); Kitty/mpv use their ordinary independent launch command. Single-instance/unknown apps show Open rather than promising a new window. No app-specific force-multi-instance arguments. All temporary input logs removed. Tests cover action selection excluding private windows and truthful labels.

### Shared Settings layout and screenshot widget (2026-09-26)
Added Appearance → Settings layout (Boxed/Grouped, default Grouped) with conditional Grouped appearance. Shared SettingsStyle, SettingsRows, SettingsGroupSurface and SettingsDivider now drive schema sections, material editor and custom Card containers; input controls receive per-row boxes in Boxed mode. Config-backed background, density (inherit/compact/normal/spacious), inner/content padding, group/row/title/description spacing, separators/inset/style/opacity. New materials.settingsGroups instance flows through existing ThemeLogic and GlassSurface with All-surfaces linking and light/dark palette; exposes transparency, blur, tint, border/width/opacity/colour, radius, shadow, glow. Density profiles retained as central derived tokens. Internal group radius is not limited by compositor window clipping. Blur is shared at the Settings-window level and explained in UI (no local fake blur engine). Boxed hides grouped controls; stored values survive toggles. Live screenshots reviewed for Grouped/Boxed and restored default Grouped. Tests cover overrides/linking, density, radius, zero layer mask, boxed isolation and compositor blur.
Screenshot widget added to registry/WidgetHost and tests. Camera button invokes existing bin/bifrost-screenshot region through Platform.launch: selection saves in XDG Pictures/Screenshots and copies to clipboard. No shortcut/default widget layout changed. Existing screenshot pipeline reused.
Validation: 515 QML / 41 CLI tests pass, validate and required doctor checks and hypr verify pass. Added missing Swedish strings from concurrent unfinished Keybinds UI to keep the translation suite complete; its implementation changes remain unstaged.

### Dock + top bar auto-hide startup race (Codex, 2026-09-26)
- Confirmed live: hyprctl had DP-2/workspace 1 while shell IPC had monitors=[] and workspace id -1. Both dock.autohide and bar.autohide.enabled/smart were true. Missing monitors make windowsCover false AND pointerIn return unknown, so both smart hide and the final pointer check keep surfaces visible. No evidence of a config or input-region defect.
- Earlier cae1c7b readiness wait was insufficient: HyprlandBackend Component.onCompleted itself called update-only refreshMonitors/refreshWorkspaces before Quickshell's asynchronous j/status completed. Quickshell 0.3.1 drops the initial canCreate=true requests when requestingMonitors/requestingWorkspaces are already set. Empty models then persist. This is also a plausible explanation for the earlier nested failures; those were not rerun here.
- Removed eager refresh calls and gated event refresh/geometry polling until native monitors exist. Quickshell owns initial seeding. No Dock/bar design changes, Display logic, generated configuration or session-unit changes.
- Added tools/test_hyprland_startup.py to selftest: real backend + fake Hyprland sockets with delayed status/data. Reproduces empty monitors on pre-fix HEAD; passes with fix and checks workspace association.
- Real bifrost.service restart verified populated DP-2/workspace 1 before and after fix (restart alone can win the race). Service accessible here with systemctl --user --machine=ragnar@.host; production IPC path uses installed symlink, not canonical repo path. Direct greetd/start-hyprland session; UWSM not independently tested.
- Validation: 532 QML checks, 44 CLI tests; validate OK, doctor required dependencies pass. Sandbox rendering/PipeWire warnings and a test-environment hyprctl version probe warning were emitted; all assertions passed. User confirmed the restart fix, then explicitly confirmed the requested logout/login test through the Bifrost greeter: both Dock and top bar hide, reveal at their screen edges, and hide again when the pointer leaves. Regression resolved (a60f441).

### Clean copy installation and XDG config hook (Codex, 2026-09-26)
- Ran install.sh --yes --no-enable --no-greeter, repeat update, and uninstall in bubblewrap with a temporary home mount and stubbed systemctl. Real user configuration and services were untouched. The bundled icon archive was actually extracted and generated Hyprland configuration verified.
- Found an XDG_CONFIG_HOME mismatch: generation respected the custom config directory but the installed Hyprland dofile hook always loaded ~/.config. Installer hook and CLI-generated guidance now respect XDG_CONFIG_HOME with the normal HOME fallback. Updating replaces only the exact legacy hook inside the installer-owned markers, with a backup; hand-written hooks remain unchanged.
- tools/test_install.py covers copy (not symlink), command links, portable service path, executable Lua hook resolution with custom/default config, legacy-hook upgrade/backup, obsolete file removal, single hook after update, uninstall and retained config. Run explicitly; requires bwrap and lua as test tools. No host service or greeter installation was performed.
- Full selftest: 532 QML / 44 CLI plus startup regression passed; validate and bash syntax passed. Known sandbox graphics/PipeWire/version-probe warnings persist. #35 still needs a real fresh-user session; #36 and manual shortcut-recording/idle tests remain open. Display untouched.

### Default launcher and overview artwork (2026-09-26)
- Bundled the user's supplied app-launcher.svg and overview.svg unchanged under assets/icons. DockItem now loads these two defaults through Paths.assetsDir, preserving full colour/gradients and existing hover/click behaviour. Trash continues to use the selected icon theme. No personal source path is stored in runtime code.
- Existing copy installer includes assets automatically, so new installations receive the same defaults; no per-user icon-theme installation or config migration is needed. Production hot reload completed without errors.
- Validation: SVG XML parsed and previews rendered; 532 QML / 44 CLI checks plus startup regression passed, validate OK. Isolated installer smoke test also checks both installed SVGs byte-for-byte.

### Fedora 44 / Ubuntu 26.04 installer support (2026-09-26)
- Added opt-in `install.sh --install-deps` and read-only `--deps-plan`. Distro/package/repository recipes and version checks live in dependencies.json. Fedora uses dnf5-plugins + lionheartp/Hyprland and errornointernet/quickshell COPRs; Ubuntu uses Universe + cppiber/hyprland and avengemedia/danklinux PPAs. `--yes` alone does not touch packages; `--install-deps --yes` accepts the printed package plan. Unknown releases stop automatic package provisioning but can use normal installation after manually satisfying dependencies. No package commands were run on the host.
- Shared tools/dependencies.py serves installer preflight and bifrostctl doctor; checks actual Hyprland --version offline, Quickshell, Qt, QML modules (including Polkit/Greetd/SVG package support in recipes) and installation/session tools. Qt paths include Fedora qtpaths-qt6/lib64 and Ubuntu qtpaths6; shader build resolves qsb through the same manifest. Doctor gives distro-specific hints.
- Fresh homes can receive a minimal marked Lua config; existing .conf is preserved and requires conversion or --no-hypr. Installed bifrost-session.target supplies graphical-session.target for plain Hyprland; generated startup imports environment, resets shell failure state, starts the target only when no graphical session is active, then starts the shell. Existing UWSM/session target remains in control. Generated config verification failures now stop installation. Existing user's compositor configuration was not regenerated/applied.
- README replaced stale pre-UI instructions; docs/INSTALL.md documents commands, community repositories, optional separate greeter and verification limits. No Display implementation changes.
- Verified live repository metadata: Ubuntu Resolute amd64 PPA Hyprland 0.56.2 / Quickshell 0.3.1; Fedora 44 x86_64 COPRs likewise. All Ubuntu recipe packages present in official/PPA indexes.
- Tests: 532 QML, 44 CLI, startup regression and 9 dependency tests pass; isolated installer verifies Fedora/Ubuntu os-release selection and package argv (package managers/sudo stubbed), old-version rejection before copy, fresh Lua config verified by actual Hyprland, copied icons, update/uninstall, legacy hook backup and preservation of existing .conf. Rendered systemd units verify successfully; validate and required doctor checks pass. Existing sandbox graphics/PipeWire/version-probe warnings remain.
- Native Fedora/Ubuntu package transactions and full graphical login have NOT been tested: no VM/container runtime was available. Do not describe the stubbed installer test as a native distro test. Next verification is a fresh Fedora 44 / Ubuntu 26.04 VM login using the documented command.

### Fedora 44 clean-install repair (2026-09-27)
- Current Fedora installation is a COPY, not the historic linked CachyOS installation. UWSM graphical session and compositor monitor/workspace tracking confirmed.
- Exec.runOptional checks executables safely with positional argv, caches missing tools until restart and always delivers an exit code. GPU, power profiles and PIA use it; missing PIA falls through to NetworkManager. Power actions require an available profile.
- ActiveWindowWidget measures independent TextMetrics rather than a width-constrained Text implicitWidth. Installer adds hidden desktop entries matching bifrost.shell and bifrost.settings for host portal registration, and removes them on uninstall.
- QML regression checks cover missing-tool completion/cache and literal argv. Fedora startup harness now logs results at info level and supplies a version reply. 535 QML, 44 CLI, delayed IPC startup and 9 dependency checks pass. Full install suite blocked by missing test-only lua interpreter after its first copy install passed; no system packages installed.
- FullBlue already resolves as default (22281 icons). Dock autohide was configured false, smartHide true. Polkit status registered=true; earlier conflict was from an older session. Logout/login not forced.
