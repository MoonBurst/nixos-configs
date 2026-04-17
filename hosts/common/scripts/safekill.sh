#!/usr/bin/env bash

# Find the binaries dynamically
SWAY_MSG=$(command -v swaymsg)
JQ=$(command -v jq)

if [ -z "$SWAY_MSG" ]; then
    notify-send "Error" "swaymsg not found"
    exit 1
fi

TARGET_ID=$($SWAY_MSG -t get_tree | $JQ -r '.. | select(.focused?) | (.app_id // .window_properties.class)')
EXCLUSION_LIST="gamescope|geany"

if echo "$TARGET_ID" | grep -qvE "^($EXCLUSION_LIST)$"; then
    $SWAY_MSG [ con_id=__focused__ ] kill
else
    notify-send "Sway" "Cannot kill excluded app: $TARGET_ID"
    exit 0
fi
