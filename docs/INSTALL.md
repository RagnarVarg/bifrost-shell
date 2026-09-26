# Install Bifrost

The dependency installer targets **Fedora 44** and **Ubuntu 26.04 LTS**
(including 26.04.1). Arch/CachyOS continues to work with dependencies installed
separately. Run the installer as your normal desktop user, from this checkout.
Python 3 must already be installed; only package operations use sudo.

```sh
./install.sh --deps-plan       # show repositories and package commands; no changes
./install.sh --install-deps    # confirm the package plan, install dependencies, install Bifrost
```

For unattended use, `--install-deps --yes` accepts the displayed package plan
and the per-user installation questions. `--yes` alone never installs system
packages. A failed package command or missing/old required runtime stops the
installer. The version requirements in `dependencies.json` are checked again
after installing packages, before copying Bifrost files. Hyprland need not be
running for this check.

## Package sources

Fedora uses `dnf5-plugins` and the `lionheartp/Hyprland` and
`errornointernet/quickshell` COPRs. Ubuntu enables Universe plus
`ppa:cppiber/hyprland` and `ppa:avengemedia/danklinux`. These are community
repositories. They remain configured for future package updates; uninstalling
Bifrost does not remove repositories or shared dependencies.

The package plan requests Hyprland, Quickshell, Qt runtime modules (including
SVG support), Python/GObject, session tools, portals, audio/network helpers,
screenshot tools and Kitty. It does not install DMS or replace the display
manager. Package managers may install dependencies of the requested packages.
Fonts not available in the repositories fall back to system fonts.

Sources checked on 2026-09-26:

- [Hyprland installation guide](https://wiki.hypr.land/getting-started/installation/)
- [Quickshell installation guide](https://quickshell.org/docs/v0.3.0/guide/install-setup/)
- [Hyprland Ubuntu PPA](https://launchpad.net/~cppiber/+archive/ubuntu/hyprland)
- [Quickshell Ubuntu PPA](https://launchpad.net/~avengemedia/+archive/ubuntu/danklinux)

Live repository indexes provided Hyprland 0.56.2 and Quickshell 0.3.1 for Ubuntu
Resolute amd64 and Fedora 44 x86_64. Versions can change; the installed binaries
and required QML modules are always checked, rather than trusting package names.
All repository commands and package lists live in `dependencies.json`.

## First login

On a fresh home the installer offers to create a minimal `hyprland.lua` with
a preferred monitor mode and the Bifrost hook. Choose **Hyprland** in your
existing login screen. The generated startup hook imports the display
environment and starts the shell. If no graphical session target is active,
it starts the installed `bifrost-session.target`; an existing UWSM/session
manager's graphical target is retained.

An existing `hyprland.conf` is not converted or overwritten. Convert it to Lua
first, or pass `--no-hypr` to install Bifrost without hooking the compositor.
Existing Lua configurations receive the installer-owned hook with a backup.
The installer does not change an existing compositor's monitor configuration.

The Bifrost greetd login screen remains optional and separate. The dependency
recipe does not install or enable greetd, stop GDM/SDDM, or install a fallback
greeter. Keep your current login screen for the first session test.

```sh
~/.local/bin/bifrostctl doctor
~/.local/bin/bifrostctl validate
```

For a development link use `--link`. To leave the shell service disabled use
`--no-enable`. To skip the greeter offer use `--no-greeter`.

## Verification status

The automated tests cover distro selection, package command ordering and
failure handling, version/module checks, Qt executable discovery, fresh Lua
config creation, installation/update/uninstallation and bundled assets.
Package commands are stubbed in the isolated installer test. The actual runtime
tests currently run on Arch/CachyOS; a complete graphical login on native
Fedora/Ubuntu hardware or VMs is **not yet verified**. A successful package
preflight is not a substitute for that final login test.

```sh
scripts/selftest.sh
python3 tools/test_install.py   # requires bubblewrap and Lua; uses a temporary home
```
