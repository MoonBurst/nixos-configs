#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# --- Threshold Definitions (in GiB) ---
RED_THRESHOLD=8    # Critical threshold: less than this is RED
WARN_THRESHOLD=16  # Warning threshold: less than this (but >= RED_THRESHOLD) is ORANGE

# --- Color Definitions ---
COLOR_CRITICAL="#FF0000"     # Red color for critically low memory
COLOR_WARNING="#FFA500"      # Orange/Amber color for warning memory
COLOR_SUFFICIENT="#00FF00"   # Green color for sufficient memory
COLOR_PADDING="#262626"      # Gray color for N/A

# --- Main Monitoring Function ---
monitor_ram() {
    # Extract the 'available' memory in GiB.
    # The '$7' column on the 'Mem' line usually corresponds to 'available' memory when using 'free -g'.
    local available_memory
    available_memory=$(free -g | awk '/Mem/ {print $7}')

    # Check if memory reading was successful and is a number
    # If the output is missing or not a number (e.g., if 'free' output changes), return N/A status.
    if ! [[ "$available_memory" =~ ^[0-9]+$ ]]; then
        echo "<span foreground='$COLOR_PADDING'>RAM: N/A</span>"
        return
    fi
    
    local color="$COLOR_SUFFICIENT"

    # Determine color based on thresholds
    if (( available_memory < RED_THRESHOLD )); then
        color="$COLOR_CRITICAL"
    elif (( available_memory < WARN_THRESHOLD )); then
        color="$COLOR_WARNING"
    fi

    # Print the available memory in the specified color using Pango markup.
    echo "<span foreground='$color'>RAM: $available_memory GiB</span>"
}

while true; do
    monitor_ram
    sleep 1
done
