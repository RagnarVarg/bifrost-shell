# Settings-audit — 2026-09-26

## Beslut och avgränsning

233 schema-inställningar inventerade nedan. Detta är en kod- och schemaaudit, inte ett påstående om att varje inställning har provats interaktivt på all hårdvara. Kolumnen apply visar deklarerat beteende; Hyprland-inställningar kräver att integrationen är aktiverad. Alla schema-värden går genom Config/CLI-validering och sparas i config.json; null är avsiktlig arv/default där schema tillåter det. Materials använder gemensam arvskedja och bevarar lokala värden när Link all surfaces växlas. Inga bevisade döda schema-nycklar tas bort på grund av enbart textsökning.

## Föreslagen struktur inför godkännande

- **Behåll** nuvarande Appearance, Shell, Widgets, Network, Bluetooth och Displays. Separat Audio-sida har inget belagt behov; CC har redan enheter och profiler.
- **Flytta till Advanced** kommandon, PAM, compositor-policy, diagnostik, import/export och rå konfiguration. Ingen sådan stor navigationsändring har gjorts.
- **Lägg till** en Input-sida med capability-kontroller, en riktig keybind-lista med redigering/konflikter och idle/screen-timeout. Dessa funktioner saknas fortfarande; de har inte ersatts av verkningslösa reglage.
- **Lägg till efter backend-verifiering** display rotation, HDR/10-bit/color management. Befintlig sida exponerar upplösning, frekvens, skala, position, VRR och delad fysisk ljusstyrka. Primary-monitor-semantik måste först definieras för Hyprland.
- **Lägg till** explicit första veckodag om en separat override behövs; nu följer kalendern locale.
- **Behåll** launcher-placement och workspace capture/map/wallpaper. Endast godkänd visuell preview-polish är gjord.

## Fynd och åtgärder

| Område | Bedömning |
|---|---|
| Shared layout | SettingRow delar upp etikett/editor på smal bredd; beskrivningar och segment wrappar. 48 fall vid 320/520/800/1400 och 100/150 % textstorlek. DisplayPage hade en separat överlappande rad; den är nu också begränsad och staplas. Alla custom-sidor är inte interaktivt testade vid alla skalor. |
| Theme | Tinted katalog, 351 giltiga Base16-paletter vid hämtning, install/apply/update/remove och cache. Palettpreview, inte en skärmbild av komplett separat shell-layout. |
| Icons | FullBlue implicit default i båda lägen; explicit anpassat val bevaras. Offline-installation verifierad. |
| Panel/frame | Interaktivt band matchar reserverad kant; fyrkantig yttre ram och delad window-radius. Verklig Vivaldi-hovermatris återstår. |
| Widgets | Battery capability-gated; Media använder gemensam MPRIS-service och spelarselektion. Ej implementerade registry-val döljs. |
| Network | Delad profil/interface-state och VPN, IPv4/6, DNS/routes/metered/autoconnect/proxy, dolda open/WPA-personal nät. Enterprise kräver valfri extern editor. Sparade ändringar gäller vid återanslutning. Live nätverksmutationer är inte testade här. |
| Brightness | Samma fysiska backend i CC/Settings; backlight och DDC per skärm. På denna maskin hittades ingen skrivbar enhet. Mock verifierar rå maxnivå och bussidentitet. |
| Bluetooth | Befintlig shared service/UI bevarad. Pair/reconnect/battery/error kräver enhetstest. |
| Keybinds | Grupper, disable/custom och central generator finns; full grafisk bind-editor och konfliktpresentation saknas. |
| Language | Svenska strängar och engelska källtexter; central font-layout testad. Full språkvisuell regression återstår. |
| Defaults | Systemstatus-kommandot använder fortfarande kitty/btop; valfritt override, bör bytas till terminaloberoende launch som separat kompatibilitetsfix. Inga användarvärden skrivs över. |
| Advanced | PAM/layerRules markerade advanced; nuvarande struktur behöver samlad navigation. Inte omdesignad utan godkännande. |
| Dead code | Oanvända frame-side input Items borttagna. Inga nya parallella theme/audio/network-state-system. |

## Per inställning

Backendkolumnen anger den centrala konsumenten, inte ett individuellt hårdvarutest. UI är schemagenererad om inget annat anges. `live` kan fortfarande vara beroende av enhet/compositor. Arv och externa OS-inställningar är avsiktliga beroenden, inte dolda lokala overrides. Behåll betyder att ingen borttagning eller sammanslagning är motiverad av denna granskning.

| Nyckel | Namn | Default | Backend | Apply | UI / beslut |
|---|---|---|---|---|---|
| `appearance.theme` | Theme | `"bifrost-graphite"` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.mode` | Light or dark | `"dark"` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.syncSystem` | Apply to apps | `true` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.location.latitude` | Latitude | `null` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.location.longitude` | Longitude | `null` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.accent` | Accent colour | `null` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.density` | Density | `"standard"` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.radiusScale` | Corner radius | `1.0` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.spacingScale` | Spacing scale | `1.0` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.prism.enabled` | Bifrost prism | `true` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `appearance.prism.intensity` | Prism intensity | `1.0` | Theme / SystemAppearance / Sun | live / shell | Behåll |
| `wallpaper.path` | Image | `""` | Wallpapers | live / shell | Behåll |
| `wallpaper.directory` | Folder to choose from | `"~/Pictures/Wallpapers"` | Wallpapers | live / shell | Behåll |
| `wallpaper.fillMode` | Scaling | `"fill"` | Wallpapers | live / shell | Behåll |
| `wallpaper.transitionMs` | Transition | `600` | Wallpapers | live / shell | Behåll |
| `materials.link` | Link all surfaces | `false` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.all.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.blur` | Background blur | `20` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.all.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.glow` | Prism glow | `0` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.border` | Border | `true` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.all.shadow` | Shadow | `1` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.bar.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.bar.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.dock.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.dock.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.menus.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.menus.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.launcher.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.launcher.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.controlCenter.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.controlCenter.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.notifications.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.notifications.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.settings.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.settings.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.transparency` | Transparency | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.blur` | Background blur | `null` | ThemeLogic / Theme / material_style | live / hyprland | Behåll |
| `materials.osd.tint` | Tint | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.thickness` | Glass thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.grain` | Grain | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.refraction` | Refraction | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.glow` | Prism glow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.border` | Border | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.borderWidth` | Border thickness | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.borderOpacity` | Border opacity | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.borderColor` | Border colour | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.radius` | Corner radius | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `materials.osd.shadow` | Shadow | `null` | ThemeLogic / Theme / material_style | live / shell | Behåll |
| `appearance.font.ui` | UI font | `null` | Theme / IconTheme / SystemAppearance | live / shell | Behåll |
| `appearance.font.mono` | Monospace | `null` | Theme / IconTheme / SystemAppearance | live / shell | Behåll |
| `appearance.font.scale` | Text size | `1.0` | Theme / IconTheme / SystemAppearance | live / shell | Behåll |
| `appearance.icons.theme` | App icon theme | `null` | Theme / IconTheme / SystemAppearance | live / shell | Behåll |
| `appearance.motion.enabled` | Animations | `true` | Theme / Motion | live / shell | Behåll |
| `appearance.motion.speed` | Speed | `1.0` | Theme / Motion | live / shell | Behåll |
| `bar.enabled` | Show bar | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.screens` | Displays | `["all"]` | Metrics / BarWindow / BarZone / WidgetHost | reload / shell | Behåll |
| `bar.layout` | Layout | `"bar"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.position` | Position | `"top"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.frame.thickness` | Frame thickness | `6` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.height` | Height | `38` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.margin` | Distance to screen edge | `8` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.spacing` | Widget spacing | `6` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.style` | Style | `"floating"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.background` | Panel background | `"panel"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.widgetStyle` | Widgets | `"integrated"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.autohide.enabled` | Autohide | `false` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.autohide.smart` | Smart | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.autohide.delayMs` | Autohide delay | `250` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.autohide.pinWhilePopupOpen` | Keep visible while a popup is open | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.menus.openOnHover` | Open menus on hover | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.menus.hoverDelayMs` | Delay before a menu opens | `120` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.menus.closeOnLeave` | Close menus when the pointer leaves them | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.menus.closeDelayMs` | Delay before a menu closes | `150` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.menus.contentTopPadding` | Extra space at the top of menus | `0` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.systemStatus.clickCommand` | Click opens | `"kitty -e btop"` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Flytta till Advanced (förslag) |
| `bar.widgets` | Widgets | `{"left":[{"id":"power"},{"id":"launcher"},{"id":"workspaces"},{"id":"activeWindow"}],"center":[{"id":"clock"}],"right":[{"id":"systemStats"},{"id":"gpu"},{"id":"tray"},{"id":"notifications"},{"id":"display"},{"id":"status"},{"id":"controlCenter"},{"id":"settings"}]}` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `bar.battery.showPercentage` | Show battery percentage | `true` | Metrics / BarWindow / BarZone / WidgetHost | live / shell | Behåll |
| `workspaces.persistent` | Always shown | `5` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.labels` | Labels | `"numbers"` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.showEmpty` | Show empty | `true` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.perMonitor` | Per display | `true` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.scroll` | Switch with the scroll wheel | `true` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.preview` | Preview on hover | `true` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `workspaces.previewLive` | Live window pictures | `true` | Compositor / WorkspacesWidget / WorkspacePreview | live / shell | Behåll |
| `launcher.placement` | Placement | `"dock"` | Launcher / AppsProvider | live / shell | Behåll |
| `launcher.columns` | Columns | `6` | Launcher / AppsProvider | live / shell | Behåll |
| `launcher.iconSize` | Icon size | `48` | Launcher / AppsProvider | live / shell | Behåll |
| `launcher.hidden` | Hidden apps | `[]` | Launcher / AppsProvider | live / shell | Behåll |
| `dock.enabled` | Show dock | `true` | Dock / DockModel | live / shell | Behåll |
| `dock.autohide` | Autohide | `false` | Dock / DockModel | live / shell | Behåll |
| `dock.smartHide` | Smart | `true` | Dock / DockModel | live / shell | Behåll |
| `dock.iconSize` | Icon size | `40` | Dock / DockModel | live / shell | Behåll |
| `dock.margin` | Distance to screen edge | `10` | Dock / DockModel | live / shell | Behåll |
| `dock.showRunning` | Show running apps | `true` | Dock / DockModel | live / shell | Behåll |
| `dock.pinned` | Pinned apps | `[]` | Dock / DockModel | live / shell | Behåll |
| `controlCenter.placement` | Placement | `"bar"` | ControlCenterContent / Audio | live / shell | Behåll |
| `controlCenter.showSystem` | System status | `true` | ControlCenterContent / Audio | live / shell | Behåll |
| `controlCenter.showMedia` | Media | `true` | ControlCenterContent / Audio | live / shell | Behåll |
| `controlCenter.showMicrophone` | Microphone slider | `false` | ControlCenterContent / Audio | live / shell | Behåll |
| `controlCenter.volumeStep` | Volume step | `5` | ControlCenterContent / Audio | live / shell | Behåll |
| `osd.enabled` | Show the OSD for volume and brightness | `true` | Osd | live / shell | Behåll |
| `osd.position` | Position | `"bottom"` | Osd | live / shell | Behåll |
| `osd.timeoutMs` | Display time | `1400` | Osd | live / shell | Behåll |
| `notifications.server` | Bifrost handles notifications | `true` | Notifications / NotificationCenter (oförändrat) | restart / shell | Behåll |
| `notifications.position` | Position | `"top-right"` | Notifications / NotificationCenter (oförändrat) | live / shell | Behåll |
| `notifications.timeoutMs` | Display time | `5000` | Notifications / NotificationCenter (oförändrat) | live / shell | Behåll |
| `notifications.doNotDisturb` | Do not disturb | `false` | Notifications / NotificationCenter (oförändrat) | live / shell | Behåll |
| `notifications.maxVisible` | Popups at once | `4` | Notifications / NotificationCenter (oförändrat) | live / shell | Behåll |
| `notifications.historyLimit` | Kept in the notification center | `50` | Notifications / NotificationCenter (oförändrat) | live / shell | Behåll |
| `lock.showClock` | Show clock | `true` | Lock | live / shell | Behåll |
| `lock.showMedia` | Show media | `true` | Lock | live / shell | Behåll |
| `lock.pamService` | PAM service | `"login"` | Lock | reload / shell | Flytta till Advanced (förslag) |
| `power.confirm` | Confirm | `true` | Power / PowerMenu | live / shell | Behåll |
| `power.softwareApp` | Software app | `""` | Power / PowerMenu | live / shell | Flytta till Advanced (förslag) |
| `clock.format` | Time format | `"24h"` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.showSeconds` | Show seconds | `false` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.showDate` | Show date | `true` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.dateFormat` | Date format | `"ddd d MMM"` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.weekNumber` | Show week number | `false` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.locale` | Date language | `"system"` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.menu.weather` | Weather | `true` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.menu.temperatureUnit` | Temperature unit | `"celsius"` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `clock.menu.media` | Now playing | `true` | ClockWidget / ClockMenu / Weather | live / shell | Behåll |
| `systemStats.intervalMs` | Update interval | `2000` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `systemStats.showCpu` | Show CPU | `true` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `systemStats.showRam` | Show RAM | `true` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `systemStats.ramUnit` | Show RAM as | `"percent"` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `systemStats.warnPercent` | Warning level | `85` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `gpu.show` | GPU shows | `"both"` | SystemStats / SystemStatusPopup | live / shell | Behåll |
| `keybinds.enabled` | Bifrost keybindings | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.terminal` | Terminal | `""` | bifrostctl keybind generator / HyprlandApply | live / shell | Flytta till Advanced (förslag) |
| `keybinds.workspaceStyle` | Super + number | `"focus"` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.groups.shell` | Bifrost | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.groups.media` | Volume, media & brightness keys | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.groups.screenshots` | Screenshots | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.groups.windows` | Window management | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.groups.workspaces` | Workspaces | `true` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.custom` | Own keybindings | `[]` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `keybinds.disabled` | Disabled keys | `[]` | bifrostctl keybind generator / HyprlandApply | live / hyprland | Behåll |
| `displays.outputs` | Display configuration | `{}` | DisplayPage / Compositor / bifrostctl | live / hyprland | Behåll, custom DisplayPage |
| `hyprland.manage` | Let Bifrost manage window appearance | `true` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.gapsIn` | Gaps between windows | `6` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.gapsOut` | Gaps to screen edges | `12` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.borderSize` | Window border | `1` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.rounding` | Window corner radius | `null` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.windows.activeTransparency` | Active window transparency | `0` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.windows.inactiveTransparency` | Inactive window transparency | `0` | HyprlandApply / bifrostctl | live / hyprland | Behåll |
| `hyprland.layerRules` | Compositor rules for Bifrost surfaces | `true` | HyprlandApply / bifrostctl | live / hyprland | Flytta till Advanced (förslag) |

## Testgränser och nästa acceptanssteg

Ren HOME/config-installation i /tmp lyckades med kopierad shell, genererad Lua och FullBlue inklusive cache/licens. Den ersätter inte separat CachyOS-SSD, första login, logout/login eller reboot. Nested Hyprland kunde inte starta Wayland-backend i denna miljö; produktionens fönster/workspaces flyttades inte för test.

Kvar: godkänn eventuell Settings-omstrukturering ovan; testa riktig SSD; Vivaldi tiled/floating × bar/frame/autohide/kanter; verklig battery/brightness/hotplug; MPRIS med flera spelare; launcher/dock högerklick; nätverksprofiler med återställningsmöjlighet; produktionens restart/persistence. Singleton/schema-ändringar motiverar kontrollerad restart före acceptans, men ingen manuell produktionsrestart utfördes.
