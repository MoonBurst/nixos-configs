#!/usr/bin/env bash

# Paths for NixOS compatibility
SYSTEMCTL="/run/current-system/sw/bin/systemctl"
RCLONE="/run/current-system/sw/bin/rclone"
JQ="/run/current-system/sw/bin/jq"
SERVICE="borgbackup-job-MoonBeauty-Offsite.service"

# 1. Error handling
if $SYSTEMCTL is-failed --quiet "$SERVICE"; then
    echo "{\"text\": \"      ERR\", \"tooltip\": \"Borg Job FAILED!\", \"class\": \"critical\"}"
    exit 0
fi

# 2. Exit if not active
if ! $SYSTEMCTL is-active --quiet "$SERVICE"; then
    echo ""
    exit 0
fi

# 3. Pull stats
STATS=$($RCLONE rc core/stats 2>/dev/null)

if [[ -z "$STATS" || "$STATS" == "{}" ]]; then
    echo "{\"text\": \"   Prep\", \"tooltip\": \"Borg is starting up...\"}"
    exit 0
fi

# 4. Extract data for manual percentage calculation
BYTES=$(echo "$STATS" | $JQ -r '.bytes // 0')
TOTAL_BYTES=$(echo "$STATS" | $JQ -r '.totalBytes // 0')
SPEED_RAW=$(echo "$STATS" | $JQ -r '.speed // 0')
SPEED=$(echo "$SPEED_RAW" | awk '{printf "%.1f KB/s", $1/1024}')
FILE=$(echo "$STATS" | $JQ -r '.transferring[0].name // "Chunks"')

# 5. Calculate percentage manually if global percentage is 0
# This prevents it from getting stuck on 'Syncing'
if [[ "$TOTAL_BYTES" -gt 0 ]]; then
    CALC_PERCENT=$(( 100 * BYTES / TOTAL_BYTES ))
else
    CALC_PERCENT=0
fi

# 6. Final Display Logic
if [[ "$CALC_PERCENT" -gt 0 ]]; then
    echo "{\"text\": \"   ${CALC_PERCENT}%\", \"tooltip\": \"File: $FILE\nSpeed: $SPEED\"}"
elif [[ $(echo "$SPEED_RAW > 0" | bc -l) -eq 1 ]]; then
    # If speed exists but percent is still 0, show the first file's progress to avoid 'Syncing'
    FILE_PERCENT=$(echo "$STATS" | $JQ -r '.transferring[0].percentage // 0')
    echo "{\"text\": \"   ${FILE_PERCENT}%\", \"tooltip\": \"Initializing global stats...\nSpeed: $SPEED\"}"
else
    echo "{\"text\": \"   Prep\", \"tooltip\": \"Waiting for data flow...\"}"
fi
