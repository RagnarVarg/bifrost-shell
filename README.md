# CachyOS shell config

Personligt anpassat Hyprland/Quickshell-skrivbord baserat på DankMaterialShell 1.6.1. Exporten innehåller shellkoden, panelen, dockan, temat, ikonerna, gesterna, workspace-overview och bildväljaren.

## Innehåll

- `config/DankMaterialShell/`: hela den anpassade DMS-shellkoden, Gruvbox Multi-temat och panel-/dockinställningar. Inter, Fira Code Nerd Font och Material Symbols ingår i shellens resurser.
- `config/hypr/`: aktiva Lua-inställningar, gester och fönsterregler.
- `config/quickshell/wallpaper-selector/`: Super+W-väljaren med tvåfingersscroll, smala kort som blir mindre utåt, enkelklick för att välja och klick utanför för att stänga.
- `icons/`: Gruvbox-Plus-Light, Bibata-Modern-Ice och standardpekartemat.
- `wallpapers/`: 15 dekorativa bakgrundsbilder, utan inbäddad metadata.
- `profiles/`: valfri skärmprofil för DP-2, 5120×1440, cirka 240 Hz.

Privata sessionsfiler, platsdata, sökhistorik, urklipp, anteckningar, konton, tokens, webbläsarprofiler och hemkatalogens övriga filer ingår inte. Mac-ljudpaketet ingår inte. Detta är en konfigurationsexport, inte en diskavbild eller komplett operativsystembackup.

## Versioner och beroenden

Exporterat från Hyprland 0.56.2 med Lua-config, libinput 1.31.3, Qt 6.11.2 och DMS 1.6.1 (shellrevision `19a5eee1e217e936`). Installera kompatibla versioner av Hyprland, DMS (`dms`), Quickshell (`qs`), Qt Quick/Qt5Compat, Python 3, jq och ImageMagick. Kitty används av terminalgenvägen. Adwaita-ikoner/-typsnitt och Noto rekommenderas som systemets fallback-resurser.

DMS-shellen är en sparad anpassad version. Framtida DMS-uppdateringar kan kräva manuell anpassning; ersätt inte automatiskt den sparade shellkoden.

## Installera efter ominstallation

1. Installera ovanstående beroenden och starta en fungerande Hyprland-session.
2. Kör `python3 install.py` för en förhandsvisning.
3. Kör `python3 install.py --apply` för att kopiera inställningarna. Befintliga filer säkerhetskopieras under `~/.local/state/cachyos-shell-config/backups/`.
4. På en matchande ultrawide-skärm kan du använda `python3 install.py --apply --ultrawide`. Annars används skärmens rekommenderade läge.
5. Om det gamla externa verktyget är installerat: `sudo systemctl disable --now three-finger-drag.service`. Det ska inte köras samtidigt med gesterna här.
6. Kör `systemctl --user daemon-reload` och `systemctl --user enable --now dms.service`. Starta om tjänsten om den redan körs. Den medföljande systemd-inställningen väljer den anpassade shellmappen. Alternativ manuell start: `dms -c "$HOME/.config/DankMaterialShell/shell" run`.
7. Kör `hyprctl reload`, följt av `hyprctl configerrors`. Kontrollera DMS med `journalctl --user -u dms.service -n 50`.
8. Välj bakgrund med Super+W. Den tidigare sessionens val och historik återställs inte.

Installationsskriptet ändrar inga tjänster, installerar inga paket och startar inte om skrivbordet automatiskt. `--target /tmp/shell-test` kan användas för att prova kopieringen i en separat katalog.

Sökvägen `@HOME@` ersätts vid installation. Paketet innehåller inga hårdkodade användarnamn. Skärmprofilen är valfri, men panelens manuella padding är utformad för 5120×1440 och kan behöva justeras på mindre skärmar.

## Trackpad

| Gest | Funktion |
|---|---|
| Tre fingrar, dra | Flytta fönster |
| Fyra fingrar upp | Växla flytande/tiling |
| Fyra fingrar ner | Stäng fönster |
| Fyra fingrar åt sidan | Byt workspace |
| Fyra fingrar ihop | Öppna overview |
| Fyra fingrar isär | Stäng overview |
| Tvåfingersscroll i Super+W | Bläddra bland bakgrundsbilder |

`tap_to_click`, `drag_lock = 1` och naturlig scrollning ingår. Pinch-namnen följer beteendet i Hyprland 0.56. Tre-finger-drag som vänster musknapp används inte; tre fingrar flyttar fönster.

## Licenser och ursprung

Se `THIRD_PARTY.md`. Ursprungliga licenser och upphovsrättsnotiser har behållits. Ingen gemensam ny licens gör anspråk på tredjepartsbilder eller andra resurser.
