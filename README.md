# Bifrost Shell

A custom Hyprland shell built with Quickshell, featuring a top bar, dock, launcher,
window overview, settings, notifications, and lock screen. Niri support is planned.

Current status and remaining work are documented in `docs/HANDOFF.md`.

## Installation

### Fedora 44 / Ubuntu 26.04 LTS

Clone the repository:

```sh
git clone https://github.com/RagnarVarg/bifrost-shell.git
cd bifrost-shell
```

Preview the dependency plan without making any changes:

```sh
./install.sh --deps-plan
```

Install the required dependencies and Bifrost:

```sh
./install.sh --install-deps
```

Run the installer as your normal user. The dependency step shows which external
package repositories will be added and uses sudo only when required.

If all required dependencies are already installed, including on Arch/CachyOS,
you can simply run:

```sh
./install.sh
```

After installation, verify the setup:

```sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

Then reboot and choose **Hyprland** from your login screen.

For more details about first login, existing Hyprland configurations, supported
distributions, and verification status, see [docs/INSTALL.md](docs/INSTALL.md).

## Development

```sh
scripts/dev.sh              # run in overlay/development mode
scripts/selftest.sh         # run tests
tools/bifrostctl doctor     # check dependencies and environment
tools/bifrostctl list bar   # inspect bar settings
```

Architecture: `docs/ARCHITECTURE.md`  
External APIs: `docs/EXTERNAL-APIS.md`
