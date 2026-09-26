# Byta från DMS till Bifrost (och tillbaka)

Bytet görs **manuellt av dig**. Varje steg går att backa. Bifrost ändrar aldrig dessa filer själv.
Kör kommandona i en terminal från repot (`~/Projects/bifrost-shell`).

## 0. Före bytet

1. `scripts/selftest.sh` ska gå igenom.
2. Kör `tools/bifrostctl doctor` och `tools/bifrostctl doctor --production`, eller Settings → Avancerat → Övergång.
3. Testa i `scripts/nested.sh`, särskilt **upplåsning med ditt lösenord** (SUPER+L) och notiser.
4. Valfritt: importera från DMS (Settings → Profiler & data → Import & export, eller
   `tools/bifrostctl import-dms --themes --apply`).

## 1. Generera Hyprland-filen

```sh
tools/bifrostctl hypr generate --write      # skriver och verifierar ~/.config/bifrost/hypr/bifrost.lua
```

Filen innehåller blur-regler för Bifrost-ytor och tangentbindningar till Bifrost. Utseende (luckor, kanter, radie, blur)
ingår bara om du har slagit på *Låt Bifrost styra Hyprland-utseende* under Settings → Avancerat → Hyprland.

## 2. Installera tjänsten (utan att starta den)

```sh
mkdir -p ~/.config/systemd/user
cp systemd/bifrost.service ~/.config/systemd/user/
systemctl --user daemon-reload
```

Tjänsten har `Conflicts=dms.service`, så de två kan aldrig köra samtidigt.

## 3. Säkerhetskopiera och ändra hyprland.lua

```sh
cp ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.pre-bifrost
```

Ändra i `~/.config/hypr/hyprland.lua`:

- Kommentera bort `require("dms.binds")`, eftersom Bifrosts fil ger motsvarande tangenter.
- **Om** Bifrost styr utseendet: kommentera också bort `require("dms.colors")` och `require("dms.layout")`.
- Behåll `dms.outputs` och `dms.cursor` (skärm och muspekare). De är statiska filer som ligger kvar.
- `dms.binds-user` är dina egna bindningar. Två gester där anropar DMS-översikten (`openOverview`/`closeOverview`)
  och fungerar inte utan DMS; kommentera bort dem eller låt dem vara (de gör då ingenting).
- Lägg till sist i filen:

  ```lua
  dofile(os.getenv("HOME") .. "/.config/bifrost/hypr/bifrost.lua")
  ```

Hyprland läser om configen när du sparar. Kontrollera med `hyprctl configerrors`, som ska vara tomt.

## 4. Byt shell

```sh
systemctl --user disable --now dms.service
systemctl --user enable --now bifrost.service
```

Kontrollera sedan:

- Bar, dock och bakgrund syns.
- `notify-send test` visar en Bifrost-popup.
- SUPER+Space öppnar launchern.
- SUPER+ALT+L låser, och det går att låsa upp.
- Volymtangenterna visar Bifrosts OSD.

Från nästa inloggning startar Bifrost automatiskt. Greetern (greetd + DMS-greeter) påverkas inte.

## Tillbaka till DMS

```sh
systemctl --user disable --now bifrost.service
systemctl --user enable --now dms.service
cp ~/.config/hypr/hyprland.lua.pre-bifrost ~/.config/hypr/hyprland.lua
```

Valfritt: `rm ~/.config/systemd/user/bifrost.service && systemctl --user daemon-reload`.
DMS-filerna och din DMS-override (`dms.service.d/override.conf`) har aldrig ändrats, så DMS är exakt som förut.

## Om skärmen blir svart eller låst

Växla till en TTY (Ctrl+Alt+F3), logga in och kör:

```sh
export XDG_RUNTIME_DIR=/run/user/$(id -u)
systemctl --user disable --now bifrost.service
systemctl --user enable --now dms.service
cp ~/.config/hypr/hyprland.lua.pre-bifrost ~/.config/hypr/hyprland.lua
```

Gå sedan tillbaka till den grafiska sessionen (Ctrl+Alt+F1 eller F2).
