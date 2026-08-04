#!/usr/bin/env bash

# Centralized binary hooks injected via Nix build contexts with local fallbacks
SWAY_MSG="${NIXOS_SWAYMSG_PATH:-swaymsg}"
HYPRCTL="hyprctl"

# Fall back to standard PATH lookups if running raw source file directly
if [[ "@jqBin@" =~ ^@.*@$ ]]; then
    JQ="jq"
else
    JQ="@jqBin@/bin/jq"
fi

EXCLUSION_LIST="gamescope|geany"

# Verify jq exists before continuing
if ! command -v "$JQ" &> /dev/null; then
    notify-send "Error" "jq command-line parser tool not found"
    exit 1
fi

# 1. Detect active desktop environment
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    SESSION_TYPE="hyprland"
elif [ -n "$SWAYSOCK" ]; then
    SESSION_TYPE="sway"
else
    # Fallback checking process tree if variables are dropped in some subshells
    if pgrep -x "Hyprland" > /dev/null; then
        SESSION_TYPE="hyprland"
    elif pgrep -x "sway" > /dev/null; then
        SESSION_TYPE="sway"
    else
        notify-send "Error" "No active Sway or Hyprland session detected."
        exit 1
    fi
fi

# 2. Extract window identifier and handle termination based on session type
if [ "$SESSION_TYPE" = "sway" ]; then
    if ! command -v "$SWAY_MSG" &> /dev/null && [ ! -f "$SWAY_MSG" ]; then
        notify-send "Error" "swaymsg not found"
        exit 1
    fi

    # Fetch focused window class parameters under Sway
    TARGET_ID=$($SWAY_MSG -t get_tree | $JQ -r '.. | select(.focused?) | (.app_id // .window_properties.class)')

    if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ]; then
        exit 0
    fi

    if echo "$TARGET_ID" | grep -qvE "^($EXCLUSION_LIST)$"; then
        $SWAY_MSG [ con_id=__focused__ ] kill
    else
        notify-send "Sway" "Cannot kill excluded app: $TARGET_ID"
        exit 0
    fi

elif [ "$SESSION_TYPE" = "hyprland" ]; then
    if ! command -v "$HYPRCTL" &> /dev/null; then
        notify-send "Error" "hyprctl not found"
        exit 1
    fi

    # Fetch active window class under Hyprland
    TARGET_ID=$($HYPRCTL activewindow -j | $JQ -r '.class')

    if [ -z "$TARGET_ID" ] || [ "$TARGET_ID" = "null" ] || [ "$TARGET_ID" = "" ]; then
        # No window focused or empty workspace desktop layer
        exit 0
    fi

    if echo "$TARGET_ID" | grep -qvE "^($EXCLUSION_LIST)$"; then
        # Explicitly wrapped the close dispatcher call inside hl.dispatch()
        $HYPRCTL dispatch 'hl.dispatch(hl.dsp.window.close())'
    else
        notify-send "Hyprland" "Cannot kill excluded app: $TARGET_ID"
        exit 0
    fi
fi
