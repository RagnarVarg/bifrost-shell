# Install Bifrost

Bifrost's automatic dependency installer currently targets **Fedora 44** and
**Ubuntu 26.04 LTS**. Arch/CachyOS is supported when the equivalent packages
are installed separately.

Run the installer as your normal desktop user. Only package operations and the
optional login-screen installation use administrator privileges.

## Recommended installation

Install Git first if the machine does not already have it:

### Fedora 44

```sh
sudo dnf install git
```

### Ubuntu 26.04

```sh
sudo apt update
sudo apt install git
```

Clone Bifrost:

```sh
git clone https://github.com/RagnarVarg/bifrost-shell.git
cd bifrost-shell
```

Preview every repository and package change:

```sh
./install.sh --deps-plan
```

Install the complete supported Bifrost runtime and Bifrost itself:

```sh
./install.sh --install-deps
```

The package plan is defined in `dependencies.json`. The installer checks the
required runtime again before it copies Bifrost files.

After installation:

```sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

Then log out or reboot and choose **Hyprland**.

## What the full dependency install contains

The supported Fedora/Ubuntu package plan intentionally installs the complete
standard Bifrost feature set rather than only the minimum needed to draw the
bar and dock.

| Bifrost feature | Fedora 44 | Ubuntu 26.04 |
| --- | --- | --- |
| Shell runtime | `quickshell` | `quickshell` |
| Compositor | `hyprland` | `hyprland` |
| Qt Quick runtime | `qt6-qtbase`, `qt6-qtdeclarative`, `qt6-qtsvg`, `qt6-qtwayland`, `qt6-qtimageformats` | `qt6-base-dev-tools`, `qt6-wayland`, `libqt6svg6`, `qt6-image-formats-plugins`, required QML6 modules |
| Bifrost tools | `python3`, `python3-gobject` | `python3`, `python3-gi`, `gir1.2-glib-2.0` |
| Fonts / font discovery | `fontconfig`, `google-noto-sans-runic-fonts` | `fontconfig`, `fonts-noto-core` |
| Installation/session | `rsync`, `util-linux`, `dbus-tools`, `systemd` | `rsync`, `util-linux`, `dbus-user-session`, `dbus-bin`, `systemd` |
| Screenshots | `grim`, `slurp`, `wl-clipboard`, `libnotify`, `xdg-user-dirs` | `grim`, `slurp`, `wl-clipboard`, `libnotify-bin`, `xdg-user-dirs` |
| Networking | `NetworkManager`, `nm-connection-editor` | `network-manager`, `nm-connection-editor` |
| Bluetooth | `bluez`, `python3-gobject` | `bluez`, `python3-gi` |
| Audio | `pipewire`, `wireplumber`, `pulseaudio-utils` | `pipewire`, `wireplumber`, `pulseaudio-utils` |
| Battery / power UI | `upower`, `power-profiles-daemon` | `upower`, `power-profiles-daemon` |
| Laptop brightness | `brightnessctl` | `brightnessctl` |
| External monitor brightness | `ddcutil` | `ddcutil` |
| Authentication dialogs | `polkit` | `polkitd`, `pkexec` |
| Portals / screen sharing | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` | `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` |
| Opening files/URLs | `xdg-utils` | `xdg-utils` |
| Default terminal | `kitty` | `kitty` |
| Optional Bifrost login screen | `greetd`, `greetd-selinux`, `acl` | `greetd`, `acl`, `pkexec` |

### Why some of these packages matter

- `pulseaudio-utils` provides `pactl`, which Bifrost uses to switch
  Bluetooth audio profiles such as A2DP and headset + microphone.
- `nm-connection-editor` is used by the advanced network editor.
- `xdg-user-dirs` provides `xdg-user-dir`, used to resolve the Pictures
  directory for screenshots.
- `upower` supplies battery and AC state to the battery widget.
- `ddcutil` is used for DDC/CI brightness control on external monitors.
  The user must also have permission to access the appropriate I2C devices.
- `power-profiles-daemon` supplies `powerprofilesctl` for the power profile
  controls.
- `google-noto-sans-runic-fonts` on Fedora (or the Noto core font set on
  Ubuntu) is needed when workspace labels are set to **Runes**.
- CPU temperature does **not** require `lm_sensors`; Bifrost reads supported
  hwmon sensors directly from `/sys/class/hwmon`.

## Fedora 44 package sources

Bifrost enables:

- `lionheartp/Hyprland` COPR for Hyprland.
- `errornointernet/quickshell` COPR for Quickshell.

The installer first installs `dnf5-plugins`, then enables those repositories,
then installs the package list from `dependencies.json`.

The following packages have been explicitly verified as available for Fedora
44 during the dependency audit on 2026-09-27: `pulseaudio-utils` (provides
`pactl`), `nm-connection-editor`, `xdg-user-dirs`, `ddcutil`,
`power-profiles-daemon`, and `google-noto-sans-runic-fonts`.

## Ubuntu 26.04 package sources

Bifrost enables Universe plus:

- `ppa:cppiber/hyprland`
- `ppa:avengemedia/danklinux`

Ubuntu Resolute provides the supporting packages used by the full feature set,
including `pulseaudio-utils`, `nm-connection-editor`, `xdg-user-dirs`,
`ddcutil`, and `power-profiles-daemon`.

## Hardware/vendor-specific extras

These are deliberately not installed for every user:

- **NVIDIA GPU statistics:** install the NVIDIA driver/userspace package that
  provides `nvidia-smi`. Without it, the Bifrost GPU widget simply reports no
  NVIDIA source.
- **Private Internet Access:** install the official PIA client if you want the
  PIA-specific VPN status/toggle. NetworkManager VPN and WireGuard profiles work
  through NetworkManager without PIA.
- **External DDC/CI brightness:** the monitor must support DDC/CI and Linux must
  expose a usable I2C device. Installing `ddcutil` alone cannot make unsupported
  hardware support DDC.
- **Geist / Geist Mono:** these are Bifrost's preferred UI fonts. They are
  recommended but not required; Bifrost falls back to the system sans/mono
  fonts when they are unavailable.

`hyprland-guiutils` is a useful Hyprland companion package, but the current
Bifrost runtime does not directly invoke it, so it is not classified as a
Bifrost runtime dependency.

## Quickshell modules required by Bifrost

The dependency check verifies that the installed Quickshell/Qt stack provides:

- `Quickshell`
- `Quickshell.Io`
- `Quickshell.Wayland`
- `Quickshell.Hyprland`
- `Quickshell.Widgets`
- `Quickshell.DBusMenu`
- `Quickshell.Services.SystemTray`
- `Quickshell.Services.Notifications`
- `Quickshell.Services.Mpris`
- `Quickshell.Services.Pipewire`
- `Quickshell.Services.UPower`
- `Quickshell.Services.Pam`
- `Quickshell.Bluetooth`
- `Quickshell.Networking`
- `Quickshell.Services.Polkit`
- `Quickshell.Services.Greetd`
- `QtQuick`
- `QtQuick.Effects`
- `Qt.labs.folderlistmodel`

If these imports are missing, installing only the executable named `qs` is
not enough for the complete shell.

## Minimum supported versions

The authoritative versions are in `dependencies.json`.

At the time of this audit:

- Hyprland: **0.55.0 or newer**; tested with **0.56.2**.
- Quickshell: **0.3.0 or newer**; tested with **0.3.1**.
- Qt: **6.8.0 or newer**.
- Python: **3.10 or newer**.

Hyprland must use the Lua config provider for Bifrost's current input/output
configuration backend. The installer does not convert an existing
`hyprland.conf` to Lua.

## First login and existing Hyprland configs

On a fresh home the installer can create a minimal `hyprland.lua` and add the
Bifrost hook.

An existing `hyprland.conf` is not overwritten or converted. Convert it to
Lua first, or use:

```sh
./install.sh --no-hypr
```

Existing Lua configurations receive only the installer-owned Bifrost hook, and
the installer makes a backup before editing the file.

## Login screen

The Bifrost login screen is optional. The installer can install its greetd
files without replacing the active display manager. It can later be enabled
from Bifrost Settings. The current graphical session is never intentionally
stopped by the enable/disable operation.

Skip all greeter installation with:

```sh
./install.sh --install-deps --no-greeter
```

## Arch / CachyOS

There is currently no automatic package transaction for Arch-based systems.
Install the equivalent packages first and then run:

```sh
./install.sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

The dependency manifest contains Arch install hints for individual
dependencies. Bifrost has been exercised most heavily on Arch/CachyOS and
Fedora during development.

## Development-only dependencies

Normal users do not need the shader compiler because compiled `.qsb` files
are committed.

To rebuild shaders, install the Qt Shader Tools package:

- Fedora: `qt6-qtshadertools`
- Ubuntu: `qt6-shader-baker`
- Arch: `qt6-shadertools`

The isolated installer test additionally needs its test tooling (for example
bubblewrap and Lua); those are development/test dependencies, not runtime
requirements.

## Useful installer modes

```sh
./install.sh --deps-plan
./install.sh --install-deps
./install.sh --install-deps --yes
./install.sh --link
./install.sh --no-hypr
./install.sh --no-greeter
./install.sh --no-enable
./install.sh --uninstall
```

Use `--link` while developing Bifrost: the installed data directory becomes a
symlink to the checkout, so source changes are used directly.

## Verification status

Run:

```sh
scripts/selftest.sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

The dependency manifest and installer tests cover the supported distro package
plans, required runtime checks, QML module discovery, installation/update and
uninstallation paths. Hardware-specific features still depend on the hardware
and services actually present on the machine.
