#!/usr/bin/env bash

# Use absolute paths for NixOS systemd/Waybar compatibility
SYSTEMCTL="/run/current-system/sw/bin/systemctl"
RCLONE="/run/current-system/sw/bin/rclone"
JQ="/run/current-system/sw/bin/jq"

# 1. Check if the Borg job has FAILED
if $SYSTEMCTL is-failed --quiet borgbackup-job-MoonBeauty-Offsite.service; then
    # Adding the 'critical' class triggers the CSS styling
    echo "{\"text\": \"      ERR\", \"tooltip\": \"Borg Job FAILED! Click to view logs.\", \"class\": \"critical\"}"
    exit 0
fi

# 2. Check if the Borg service is actually running
if ! $SYSTEMCTL is-active --quiet borgbackup-job-MoonBeauty-Offsite.service; then
    echo ""
    exit 0
fi

# 3. Get stats from rclone
STATS=$($RCLONE rc core/stats 2>/dev/null)

# 4. Handle empty/starting states
if [[ -z "$STATS" || "$STATS" == "{}" ]]; then
    echo "{\"text\": \"   Prep\", \"tooltip\": \"Borg is starting up...\"}"
    exit 0
fi

# 5. Extract data (Using [0] for the array)
PERCENT=$(echo "$STATS" | $JQ -r '.transferring[0].percentage // empty')
FILE=$(echo "$STATS" | $JQ -r '.transferring[0].name // "Metadata"')
SPEED=$(echo "$STATS" | $JQ -r '.speed // 0' | awk '{printf "%.1f KB/s", $1/1024}')

# 6. JSON Output for Waybar
if [[ -z "$PERCENT" || "$PERCENT" == "null" ]]; then
    echo "{\"text\": \"   Prep\", \"tooltip\": \"Syncing Metadata at $SPEED\"}"
elif [[ "$PERCENT" == "0" ]]; then
    echo "{\"text\": \"   Syncing\", \"tooltip\": \"Preparing $FILE at $SPEED\"}"
else
    echo "{\"text\": \"   ${PERCENT}%\", \"tooltip\": \"File: $FILE \nSpeed: $SPEED\"}"
fi
