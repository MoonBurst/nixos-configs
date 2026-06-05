#!/usr/bin/env bash

# Centralized binary hooks injected via Nix build contexts
SWAY_MSG="${NIXOS_SWAYMSG_PATH:-swaymsg}"
JQ="@jqBin@/bin/jq"

if ! command -v "$SWAY_MSG" &> /dev/null && [ ! -f "$SWAY_MSG" ]; then
    notify-send "Error" "swaymsg not found"
    exit 1
fi

# Fetch focused window class parameters
TARGET_ID=$($SWAY_MSG -t get_tree | $JQ -r '.. | select(.focused?) | (.app_id // .window_properties.class)')
EXCLUSION_LIST="gamescope|geany"

if echo "$TARGET_ID" | grep -qvE "^($EXCLUSION_LIST)$"; then
    $SWAY_MSG [ con_id=__focused__ ] kill
else
    notify-send "Sway" "Cannot kill excluded app: $TARGET_ID"
    exit 0
fi
