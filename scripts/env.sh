# Environment shared by every Bifrost Quickshell process (shell, settings).
# Sourced by bin/bifrost-shell and scripts/settings.sh. QS_ICON_THEME makes
# Qt's own icon lookups use Bifrost's icon theme from the start (Bifrost then
# switches app icons live through its own index; see Core/IconTheme.qml).
_bifrost_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$("$_bifrost_root/tools/bifrostctl" env 2>/dev/null)"
# Bifrost's own commands (bifrost-terminal, bifrost-ipc …) for what the shell
# runs – default click commands, custom commands – even when ~/.local/bin is
# not in the session's PATH (Hyprland's often isn't).
case ":$PATH:" in *":$_bifrost_root/bin:"*) ;; *) export PATH="$_bifrost_root/bin:$PATH" ;; esac
unset _bifrost_root
