#!/usr/bin/env bash
# Global floating/tiling mode toggle.
#
# Tiling (default): normal windows behave per Hyprland's usual rules.
# Floating: every existing tiled window is floated (windows that were
# already floating — via their own windowrules or manual floating — are
# left untouched) and a catch-all windowrule floats newly opened windows
# too. Toggling back settles only the windows this script itself floated.
set -euo pipefail

STATE_DIR="$HOME/.local/state/hypr-floatmode"
MODE_FILE="$STATE_DIR/mode"
FLOATED_FILE="$STATE_DIR/floated-by-toggle"
RULE_FILE="$HOME/.config/hypr/config/floatmode.lua"

mkdir -p "$STATE_DIR"

mode="tiling"
[[ -f "$MODE_FILE" ]] && mode="$(cat "$MODE_FILE")"

if [[ "$mode" == "floating" ]]; then
    # Switch back to tiling: settle only windows we floated ourselves.
    if [[ -f "$FLOATED_FILE" ]]; then
        currently_floating="$(hyprctl clients -j | jq -r '.[] | select(.floating==true) | .address')"
        while IFS= read -r addr; do
            [[ -z "$addr" ]] && continue
            if grep -qxF "$addr" <<<"$currently_floating"; then
                hyprctl dispatch "hl.dsp.window.float({ action = \"unset\", window = \"address:$addr\" })" >/dev/null
            fi
        done <"$FLOATED_FILE"
    fi
    rm -f "$FLOATED_FILE"

    cat >"$RULE_FILE" <<'EOF'
-- Floating/Tiling toggle: TILING mode. Managed by floatmode-toggle.sh — do not edit manually.
EOF

    echo "tiling" >"$MODE_FILE"
    hyprctl reload
    notify-send -a "Hyprland" "Tiling mode" "New and existing windows tile normally." 2>/dev/null || true
else
    # Switch to floating: float every currently tiled window and record it.
    : >"$FLOATED_FILE"
    hyprctl clients -j | jq -r '.[] | select(.floating==false and .mapped==true) | .address' | while IFS= read -r addr; do
        [[ -z "$addr" ]] && continue
        echo "$addr" >>"$FLOATED_FILE"
        hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$addr\" })" >/dev/null
    done

    cat >"$RULE_FILE" <<'EOF'
-- Floating/Tiling toggle: FLOATING mode. Managed by floatmode-toggle.sh — do not edit manually.
hl.window_rule({ match = { class = "^.*$" }, float = true })
EOF

    echo "floating" >"$MODE_FILE"
    hyprctl reload
    notify-send -a "Hyprland" "Floating mode" "New and existing windows are floating." 2>/dev/null || true
fi
