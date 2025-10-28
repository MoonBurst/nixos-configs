#!/bin/bash

# Enable strict mode: exit on error (-e), exit on unbound variables (-u),
# set last exit code of pipeline to non-zero if any command fails (-o pipefail).
set -euo pipefail

# A lightweight script to check Pacman and AUR updates and output clean JSON for Waybar.
# Requires 'pacman-contrib' (for checkupdates) and 'paru' or equivalent AUR helper.

# --- Configuration ---
# The regex to strip ANSI codes.
ANSI_REGEX="\[[0-9;]*m"
# ---------------------

# Check dependencies just once at startup
if ! command -v checkupdates &> /dev/null || ! command -v paru &> /dev/null; then
    # Output an error message and exit the script
    echo "Error: Required commands 'checkupdates' or 'paru' not found." >&2
    echo "{\"text\":\"ERR!\", \"tooltip\":\"Missing checkupdates/paru.\", \"class\":\"error\"}"
    exit 1
fi

# --- Functions to get and clean the lists ---

# Function to get Pacman updates and clean the output
get_pacman_updates() {
    # CRITICAL FIX: Temporarily disable pipefail because checkupdates returns non-zero when updates exist.
    ( set +o pipefail
        # Added 2>/dev/null to silence any stderr output that Waybar might interpret as an error.
        checkupdates 2>/dev/null | \
        tr -d "$(printf '\033')" | \
        sed -E 's/\[[0-9;]*m//g' | \
        awk '{print $1}' | \
        sed '/^$/d'
    )
}

# Function to get AUR updates and clean the output
get_aur_updates() {
    # CRITICAL FIX: Temporarily disable pipefail because paru -Qua returns non-zero when updates exist.
    ( set +o pipefail
        # Added 2>/dev/null to silence any stderr output that Waybar might interpret as an error.
        paru -Qua --nocolor 2>/dev/null | \
        tr -d "$(printf '\033')" | \
        sed -E 's/\[[0-9;]*m//g' | \
        awk '{print $1}' | \
        sed '/^$/d'
    )
}

# --- Main Monitoring Function (Core Logic) ---
monitor_updates() {
    local PACMAN_LIST AUR_LIST PACMAN_COUNT AUR_COUNT TOTAL_COUNT TOOLTIP_CONTENT CLEAN_TOOLTIP

    PACMAN_LIST=$(get_pacman_updates)
    AUR_LIST=$(get_aur_updates)

    # Calculate counts (handling empty list case)
    PACMAN_COUNT=$(echo "$PACMAN_LIST" | awk 'NF' | wc -l)
    AUR_COUNT=$(echo "$AUR_LIST" | awk 'NF' | wc -l)

    TOTAL_COUNT=$((PACMAN_COUNT + AUR_COUNT))

    # --- Tooltip Formatting ---

    TOOLTIP_CONTENT=""

    if [[ "$PACMAN_COUNT" -gt 0 ]]; then
        TOOLTIP_CONTENT+="Repo Updates ($PACMAN_COUNT):\n"
        # Concatenate directly.
        TOOLTIP_CONTENT+="$PACMAN_LIST\n"
    fi

    if [[ "$AUR_COUNT" -gt 0 ]]; then
        if [[ -n "$TOOLTIP_CONTENT" ]]; then
            TOOLTIP_CONTENT+="\n" # Add an extra newline between sections
        fi
        TOOLTIP_CONTENT+="AUR Updates ($AUR_COUNT):\n"
        TOOLTIP_CONTENT+="$AUR_LIST"
    fi

    # Replace all real newlines with the escaped character '\n' for JSON.
    CLEAN_TOOLTIP=$(echo -e "$TOOLTIP_CONTENT" | sed ':a;N;$!ba;s/\n/\\n/g')


    # --- JSON Output (Waybar format) ---

    if [[ "$TOTAL_COUNT" -gt 0 ]]; then
        echo "{\"text\":\"$TOTAL_COUNT\", \"tooltip\":\"$CLEAN_TOOLTIP\", \"class\":\"has-updates\"}"
    else
        # Always output a valid JSON object to avoid the Waybar JSON parsing error.
        echo "{\"text\":\"0\", \"tooltip\":\"System is up to date.\", \"class\":\"updated\"}"
    fi
}


# --- Main Execution Loop (Required for Waybar interval: 0 streaming) ---
while true; do
    monitor_updates
    sleep 60
done
