#!/usr/bin/env bash
# Per-workspace floating/tiling mode toggle.
#
# Mirrors floatmode-toggle.sh's approach (float/settle only the windows this
# script itself touches) but scoped to a single workspace instead of being
# global. The generated rule for this workspace is written explicitly
# (float = true OR float = false) so it wins over the global toggle
# (config/floatmode.lua) for any workspace the user has interacted with here.
#
# Usage: workspace-floatmode-toggle.sh [workspace_id]
#        Defaults to the currently active workspace on the focused monitor.
set -euo pipefail

STATE_ROOT="$HOME/.local/state/hypr-floatmode/workspaces"
RULE_FILE="$HOME/.config/hypr/config/floatmode-workspace.lua"

workspace_id="${1:-}"
if [[ -z "$workspace_id" ]]; then
    workspace_id="$(hyprctl activeworkspace -j | jq -r '.id')"
fi

if ! [[ "$workspace_id" =~ ^-?[0-9]+$ ]]; then
    echo "workspace-floatmode-toggle: not a normal workspace id: $workspace_id" >&2
    exit 1
fi

ws_dir="$STATE_ROOT/$workspace_id"
mode_file="$ws_dir/mode"
floated_file="$ws_dir/floated-by-toggle"
mkdir -p "$ws_dir"

mode="tiling"
[[ -f "$mode_file" ]] && mode="$(cat "$mode_file")"

regenerate_rules() {
    {
        echo "-- Per-workspace floating/tiling overrides. Managed by workspace-floatmode-toggle.sh — do not edit manually."
        echo "-- Loaded after config.floatmode so a workspace override here wins over the global floating/tiling toggle."
        for dir in "$STATE_ROOT"/*/; do
            [[ -d "$dir" ]] || continue
            ws="$(basename "$dir")"
            ws_mode_file="$dir/mode"
            [[ -f "$ws_mode_file" ]] || continue
            ws_mode="$(cat "$ws_mode_file")"
            if [[ "$ws_mode" == "floating" ]]; then
                echo "hl.window_rule({ match = { workspace = $ws }, float = true })"
            else
                echo "hl.window_rule({ match = { workspace = $ws }, float = false })"
            fi
        done
    } >"$RULE_FILE"
}

if [[ "$mode" == "floating" ]]; then
    # Switch this workspace back to tiling: settle only windows we floated.
    if [[ -f "$floated_file" ]]; then
        currently_floating="$(hyprctl clients -j | jq -r --argjson ws "$workspace_id" '.[] | select(.workspace.id==$ws and .floating==true) | .address')"
        while IFS= read -r addr; do
            [[ -z "$addr" ]] && continue
            if grep -qxF "$addr" <<<"$currently_floating"; then
                hyprctl dispatch "hl.dsp.window.float({ action = \"unset\", window = \"address:$addr\" })" >/dev/null
            fi
        done <"$floated_file"
    fi
    rm -f "$floated_file"
    echo "tiling" >"$mode_file"
    regenerate_rules
    hyprctl reload
    notify-send -a "Hyprland" "Workspace $workspace_id: tiling" "New and existing windows on this workspace tile normally." 2>/dev/null || true
else
    # Switch this workspace to floating: float every currently tiled window
    # on it and record what we floated.
    : >"$floated_file"
    hyprctl clients -j | jq -r --argjson ws "$workspace_id" '.[] | select(.workspace.id==$ws and .floating==false and .mapped==true) | .address' | while IFS= read -r addr; do
        [[ -z "$addr" ]] && continue
        echo "$addr" >>"$floated_file"
        hyprctl dispatch "hl.dsp.window.float({ action = \"set\", window = \"address:$addr\" })" >/dev/null
    done
    echo "floating" >"$mode_file"
    regenerate_rules
    hyprctl reload
    notify-send -a "Hyprland" "Workspace $workspace_id: floating" "New and existing windows on this workspace float." 2>/dev/null || true
fi
