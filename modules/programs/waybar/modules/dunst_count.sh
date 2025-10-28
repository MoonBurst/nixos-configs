#!/usr/bin/env bash
set -euo pipefail

# This script continuously monitors the Dunst notification daemon status (paused state and waiting count),
# formatting the output as Pango markup for use in status bars (like Polybar/Waybar).

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
        # Suppress errors if dunstctl fails (e.g., dunst is not running properly)
        count=$(dunstctl count waiting 2>/dev/null || echo "0")
        status=$(dunstctl is-paused 2>/dev/null || echo "false")
    else
        # If dunstctl is not found, return a simple N/A status
        echo "<span color=\"$DUNST_MUTED\">Dunst N/A</span>"
        return
    fi
    
    local icon=""
    local color=""

    if [ "$status" = "true" ]; then
        # Paused (Muted)
        icon="🔕"
        color="$DUNST_MUTED"
    elif [ "$count" -gt 0 ]; then
        # Active and has waiting notifications
        icon="🔔"
        color="$DUNST_WARN"
    else
        # Active and clear (0 waiting)
        icon="🔔"
        color="$DUNST_NORM"
    fi
    
    # Output Pango markup for the status
    echo "<span color=\"$color\">$icon $count</span>"
}
# --- Main Execution Loop (Required for Waybar interval: 0 streaming) ---
while true; do
    monitor_dunst
    sleep 1
done
