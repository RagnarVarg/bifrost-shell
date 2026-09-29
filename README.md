# Bifrost Shell

<p align="center">
  <img src="assets/brand/bifrost-logo.svg" alt="Bifrost logo" width="180">
</p>

Bifrost is a complete desktop shell for [Hyprland](https://hyprland.org), built
with [Quickshell](https://quickshell.org). It replaces the usual collection of
bars, launchers, notification daemons and settings tools with one consistent,
glass-styled desktop, configured from its own Settings app instead of
hand-edited config files.

## Features

- **Top bar**: on any screen edge, with auto-hide, widget boxes and a widget
  layout you arrange in Settings. Widgets cover workspaces (numbers or runes), the
  active window, clock, media, system stats, GPU, battery, tray,
  notifications, screenshots and a control-center button.
- **Dock**: pinned and running apps with window previews, reordering by drag,
  minimize-into-dock, auto-hide (revealed from the whole screen edge) and
  smart hide.
- **Launcher, window overview and control center**: app search, a zoomed-out
  grid of all windows, and quick toggles for Wi-Fi, Bluetooth, audio,
  brightness, VPN and power profiles.
- **Clock menu**: calendar, today's events and reminders, weather forecast and
  a media player in one panel.
- **Notifications**: popups, a notification center and on-screen displays for
  volume and brightness.
- **Lock screen, power menu and idle handling**, plus an optional greetd login
  screen that matches the desktop.
- **Settings app** for everything, including:
  - themes, accent colours and light/dark mode
  - glass: transparency, blur and tint per light/dark mode
  - fonts and icons
  - wallpapers
  - keybindings with conflict checks, per-device input and trackpad gestures
  - displays: resolution, refresh rate, scale, VRR and HDR with SDR
    brightness and saturation
- **Hardware integration**: NetworkManager, BlueZ, PipeWire, laptop and
  DDC/CI monitor brightness, UPower and power-profiles-daemon.
- **`bifrostctl`**: a command-line tool for every setting, preset, profile and
  health check.
- **Translations**: English and Swedish.

Bifrost never edits your own Hyprland files beyond a single marked hook: all
compositor settings go to a generated `~/.config/bifrost/hypr/bifrost.lua`.

## Requirements

- **Hyprland 0.55 or newer** with a **Lua config** (`hyprland.lua`); tested
  with 0.56.2. A classic `hyprland.conf` is not converted for you.
- **Quickshell 0.3 or newer**, Qt 6.8 or newer and Python 3.10 or newer.

Minimum versions and every dependency live in
[`dependencies.json`](dependencies.json).

## Installation

Run everything as your normal user; only package installation and the optional
login screen use `sudo`.

### 1. Get the source

```sh
git clone https://github.com/RagnarVarg/bifrost-shell.git
cd bifrost-shell
```

### 2. Install the dependencies

**Fedora 44 and Ubuntu 26.04 LTS**: the installer can do this for you. It
enables the Hyprland and Quickshell repositories (COPR or PPA) and installs the
full feature set.

```sh
./install.sh --deps-plan      # preview every repository and package change
./install.sh --install-deps   # install the dependencies, then Bifrost
```

**Arch Linux and CachyOS**: install the packages yourself:

```sh
sudo pacman -S --needed quickshell hyprland qt6-declarative qt6-svg qt6-wayland \
  qt6-imageformats python python-gobject rsync util-linux dbus fontconfig \
  noto-fonts xdg-user-dirs grim slurp wl-clipboard libnotify xdg-utils \
  networkmanager nm-connection-editor bluez bluez-utils pipewire wireplumber \
  libpulse upower power-profiles-daemon brightnessctl polkit \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk kitty
```

Optional extras for Arch/CachyOS:

- `ddcutil`: brightness of external monitors over DDC/CI (needs access to
  `i2c-dev`).
- `ttf-geist-variable` and `ttf-geist-mono-variable` (AUR): Bifrost's default
  fonts. Without them Bifrost falls back to your system fonts, and any font
  can be chosen in Settings.
- `greetd` and `acl`: the Bifrost login screen.
- `nvidia-utils`: the GPU widget on NVIDIA cards.

### 3. Install Bifrost

```sh
./install.sh
```

The installer:

- copies Bifrost to `~/.local/share/bifrost-shell` and links its commands
  (`bifrostctl`, `bifrost-settings`, …) into `~/.local/bin`
- installs and enables the `bifrost.service` user service
- generates `~/.config/bifrost/hypr/bifrost.lua` and, after asking, adds a
  marked hook to `hyprland.lua` (backup made first)
- offers the login screen if greetd is installed

### 4. Check and log in

```sh
bifrostctl doctor     # dependencies, versions and session checks
bifrostctl validate   # configuration check
```

Log out, choose **Hyprland**, and Bifrost starts with the session. Open
Settings with <kbd>Super</kbd> + <kbd>,</kbd> and the launcher with
<kbd>Super</kbd> + <kbd>Space</kbd>.

### Updating

```sh
git pull
./install.sh
systemctl --user restart bifrost.service
```

Your settings in `~/.config/bifrost/` are kept and migrated automatically; a
backup of the old file is stored in `~/.config/bifrost/backups/`.

### Installer options

| Option | Effect |
| --- | --- |
| `--deps-plan` | Show the Fedora/Ubuntu package plan without changing anything |
| `--install-deps` | Install the Fedora/Ubuntu dependencies first |
| `--yes` | Answer yes to every question (unattended) |
| `--no-hypr` | Don't hook `bifrost.lua` into `hyprland.lua` |
| `--no-greeter` | Don't offer the login screen |
| `--no-enable` | Install the service without enabling it |
| `--link` | Development: link the install to this checkout |
| `--uninstall` | Remove what the installer added (your settings are kept) |

The full package table per feature, the login screen and hardware notes are in
[docs/INSTALL.md](docs/INSTALL.md).

## Development

```sh
scripts/dev.sh              # run next to your session (overlay mode)
scripts/nested.sh           # run inside a nested Hyprland
scripts/selftest.sh         # tests
tools/bifrostctl doctor     # dependencies and environment
```

- `./install.sh --link` makes source changes apply directly.
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- External APIs: [docs/EXTERNAL-APIS.md](docs/EXTERNAL-APIS.md)
- Status and open work: [docs/HANDOFF.md](docs/HANDOFF.md)
