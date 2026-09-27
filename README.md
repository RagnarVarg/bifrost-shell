# Bifrost Shell

A custom Hyprland shell built with Quickshell, featuring a top bar, dock, launcher,
window overview, settings, notifications, lock screen, networking, Bluetooth,
audio, brightness, power controls, screenshots, and an optional login screen.
Niri support is planned.

Current status and remaining work are documented in `docs/HANDOFF.md`.

## Installation

### Fedora 44 / Ubuntu 26.04 LTS

Install Git first if needed, then clone the repository:

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

The supported package plan installs the full standard feature set, including
Hyprland, Quickshell, Qt/QML modules, PipeWire/WirePlumber, NetworkManager,
Bluetooth, screenshots, portals, battery/power support, external-monitor
brightness support, the Runic workspace font, Kitty, and the optional greetd
login-screen prerequisites.

After installation, verify the setup:

```sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

Then log out or reboot and choose **Hyprland**.

For the exact Fedora/Ubuntu package list, feature-to-package mapping,
hardware-specific extras, minimum versions, Quickshell modules, Arch/CachyOS
notes, and development dependencies, see
[docs/INSTALL.md](docs/INSTALL.md).

### Arch / CachyOS

Install the equivalent dependencies first, then run:

```sh
./install.sh
```

The individual Arch package hints and authoritative dependency/version data are
kept in `dependencies.json`.

## Development

```sh
scripts/dev.sh              # run in overlay/development mode
scripts/selftest.sh         # run tests
tools/bifrostctl doctor     # check dependencies and environment
tools/bifrostctl list bar   # inspect bar settings
```

For a development install where source changes apply directly:

```sh
./install.sh --link
```

Architecture: `docs/ARCHITECTURE.md`  
External APIs: `docs/EXTERNAL-APIS.md`
