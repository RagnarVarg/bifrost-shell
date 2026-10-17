# Bifrost Settings – mac-stil (branch `ui/mac-style`)

Utseendet på Bifrost Settings är omgjort med macOS System Settings som förebild: layout, luft och rytm.
Bifrosts egen identitet är kvar (grafit, glas, silverkanter, stålblå accent), och inga Apple-assets används
(projektets ikonset `assets/icons`, temats typsnitt). **Bara presentationslagret är ändrat.** `schema/`,
`shell/Core/` (Config, Schema, ApplyState, ThemeMode), IPC, `tools/bifrostctl`, nycklar och editorernas
`set()`/`Config.reset` är orörda.

## Commits

| Commit | Steg |
|---|---|
| `7f6ff3d6` | Sidomeny (sök överst, färgade ikonrutor, kategorirubriker), rader kant i kant med hårlinjer, återställ vid hover, segmenterat för 2–4 val, centrerad kolumn 680 px, in-animation vid sektionsbyte |
| `4aa0fb49` | Färgväljare som rund prick (väljare, hex och palett fälls ut), sökträffar som kort, höga rader toppjusteras |
| `ecff090c` | Egna sidor i samma mönster: navigeringsrader (Inmatning, sök), enhets- och gestrader etikett vänster/kontroll höger, rubriker i normal versalisering |
| `6e59548e` | Selftest: varje schemainställning har en rad med editor, radens återställ, val av segmenterat/popup |

Nya tokens (`themes/_base.json`): `color.tile` (färg per sektion/sida, `fallback`), `color.tileIcon`,
`control.tile` (22 px ruta, 14 px ikon, radie 6), `layout.settingsEditorWidth` (260), `layout.settingsSegmentChars` (26).
Ändrade: `layout.sidebarWidth` 248 → 220, `sidebarWideWidth` 284 → 240, `pageMaxWidth` 780 → 680,
`pageWideMaxWidth` 1040 → 720. `layout.editorWidth` (används av panelen och docken) är oförändrad.

## Testat

Automatiskt (`scripts/selftest.sh`: 623/0, bifrostctl-tester ok, `bifrostctl validate` ok):
- **Alla inställningar syns:** varje inställning som stöds i varje schemasektion får en rad vars editor har rätt
  nyckel (172/172 i testkonfigurationen). Filtret (`isSupported`, `inMode`, `hideUnlessMet`) är oförändrat.
- **Editorerna läser och skriver via Config** för alla 18 editortyper (befintligt test, ColorEditor efter omgörningen).
- **Återställ:** en ändrad rad visar återställ-knappen, och ett klick ger standardvärdet tillbaka (`Config.isModified` blir false).
- **Val av kontroll:** 4 korta val ger segmenterad kontroll (`bar.position`), 3 val segmenterad (`osd.position`),
  6 val popup-meny (`notifications.position`).
- **Text och kontroll överlappar inte** vid 320/520/800/1400 px och 1,0/1,5 i textskala (befintligt layouttest).
- **Responsivt:** kompakt/normal/brett (befintligt test, med nya tokenvärden).
- **Alla Settings-komponenter kompilerar**, även nya `SettingsNavRow`, `SettingsNavList`, `Sidebar`, `NavItem` och `SearchPage`.

Visuellt (offscreen-rendering med OpenGL, användarens config kopierad till en scratch-mapp, svenska):
- Alla 23 schemasektioner och alla egna sidor (Inmatning med undersidor, Kortkommandon, Nätverk, Bluetooth, Skärmar,
  Profiler, Import & export, Data, Hämta fler teman) vid 1180 px.
- Kompakt (700 px: tillbaka + sök överst) och brett (1560 px).
- Sök ("panel", "dock"): träffar från etikett och beskrivning. Ett klick öppnar sektionen, rullar till raden och markerar den (`SettingsNav.open`, oförändrat).
- Färgväljaren utfälld (HSV, hex, palett) och markeringen av ändrade värden (prick före etiketten).

Inte testat:
- Riktig hover med pekare och live-förhandsvisning mot det körande shellet. Inget av det rörs av ändringen, men det
  är inte provat i en riktig session. Production är en kopia-installation, så ändringarna syns först efter
  `./install.sh --no-hypr --no-greeter` + omstart av Settings.
- Ljust tema är bara kontrollerat via tokens (rutornas färger är desamma i båda lägena), inte med skärmbild.
