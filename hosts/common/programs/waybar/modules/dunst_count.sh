#!/usr/bin/env bash
set -euo pipefail

# This script monitors the Dunst notification daemon status,
# formatting the output as Pango markup with micro-shifting pixel defense.

# --- Configuration ---
WARN="#ffa500" # Orange (Used for active, waiting notifications)
NORM="#00FF00" # Green (Used for active, clear status)
DUNST_MUTED="#808080" # Grey (Used for paused state)
# ---------------------

monitor_dunst() {

    local DUNST_WARN="$WARN"
    local DUNST_NORM="$NORM"

    local count="?"
    local status="false"

    # Check if dunstctl exists and dunst is running
    if command -v dunstctl &> /dev/null; then
        count=$(dunstctl count waiting 2>/dev/null || echo "0")
        status=$(dunstctl is-paused 2>/dev/null || echo "false")
    else
        echo "<span color=\"$DUNST_MUTED\">Dunst N/A</span>"
        return
    fi

    local icon=""
    local base_color=""

    if [ "$status" = "true" ]; then
        icon="🔕"
        base_color="$DUNST_MUTED"
    elif [ "$count" -gt 0 ]; then
        icon="🔔"
        base_color="$DUNST_WARN"
    else
        icon="🔔"
        base_color="$DUNST_NORM"
    fi

    # --- Micro-Shift Engine (Anti-Burn-In) ---
    # Calculates a microscopic hex derivation every 2 minutes to oscillate pixel voltages.
    local CURRENT_MIN=$(date +%M)
    local OFFSET_DEC=$(( 10#$CURRENT_MIN / 4 )) # Variance ranges tightly from 0 to 15

    local HEX_CLEAN="${base_color#\#}"
    local R_HEX="${HEX_CLEAN:0:2}"
    local G_HEX="${HEX_CLEAN:2:2}"
    local B_HEX="${HEX_CLEAN:4:2}"

    local R_DEC=$((16#$R_HEX))
    local G_DEC=$((16#$G_HEX))
    local B_DEC=$((16#$B_HEX))

    local R_MUTATED G_MUTATED B_MUTATED
    if [ $((10#$CURRENT_MIN % 2)) -eq 0 ]; then
        R_MUTATED=$(( R_DEC + OFFSET_DEC ))
        G_MUTATED=$(( G_DEC - OFFSET_DEC ))
        B_MUTATED=$(( B_DEC + OFFSET_DEC ))
    else
        R_MUTATED=$(( R_DEC - OFFSET_DEC ))
        G_MUTATED=$(( G_DEC + OFFSET_DEC ))
        B_MUTATED=$(( B_DEC - OFFSET_DEC ))
    fi

    # Boundaries validation
    [ $R_MUTATED -gt 255 ] && R_MUTATED=255; [ $R_MUTATED -lt 0 ] && R_MUTATED=0
    [ $G_MUTATED -gt 255 ] && G_MUTATED=255; [ $G_MUTATED -lt 0 ] && G_MUTATED=0
    [ $B_MUTATED -gt 255 ] && B_MUTATED=255; [ $B_MUTATED -lt 0 ] && B_MUTATED=0

    local MUTATED_COLOR=$(printf "#%02x%02x%02x" $R_MUTATED $G_MUTATED $B_MUTATED)

    # Output Pango markup for the status
    echo "<span color=\"$MUTATED_COLOR\">$icon $count</span>"
}

monitor_dunst
