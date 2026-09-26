# Bifrost Shell

Ett eget Hyprland-shell byggt på Quickshell med top bar, Dock, launcher,
fönsteröversikt, inställningar, notiser och låsskärm. Niri-stöd är planerat.
Aktuellt läge och återstående arbete finns i `docs/HANDOFF.md`.

## Installation

Fedora 44 och Ubuntu 26.04 LTS har paketplaner för sina beroenden:

```sh
./install.sh --deps-plan
./install.sh --install-deps
```

Kör som vanlig användare. Paketsteget visar vilka externa paketkällor som läggs
till och använder sudo efter godkännande. Med beroendena redan installerade,
inklusive på Arch/CachyOS, räcker `./install.sh`.

Se [installationsguiden](docs/INSTALL.md) för första inloggning, befintlig
Hyprland-konfiguration och vad som faktiskt har testats. Full grafisk
Fedora/Ubuntu-inloggning återstår att verifiera.

## Utveckling

```sh
scripts/dev.sh              # overlay-läge
scripts/selftest.sh         # tester
tools/bifrostctl doctor     # beroenden och miljö
tools/bifrostctl list bar   # inställningar
```

Arkitektur: `docs/ARCHITECTURE.md`. Externa API:er: `docs/EXTERNAL-APIS.md`.
Bifrost har inget runtime-beroende på DMS eller Noctalia.
