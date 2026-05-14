#!/usr/bin/env bash

SYSTEMCTL="/run/current-system/sw/bin/systemctl"
RCLONE="/run/current-system/sw/bin/rclone"
JQ="/run/current-system/sw/bin/jq"
SERVICE="borgbackup-job-MoonBeauty-Offsite.service"

if $SYSTEMCTL is-failed --quiet "$SERVICE"; then
    echo "{\"text\": \"      ERR\", \"tooltip\": \"Borg Job FAILED!\", \"class\": \"critical\"}"
    exit 0
fi

if ! $SYSTEMCTL is-active --quiet "$SERVICE"; then
    echo ""
    exit 0
fi

STATS=$($RCLONE rc core/stats 2>/dev/null)
if [[ -z "$STATS" || "$STATS" == "{}" ]]; then
    echo "{\"text\": \"   Prep\", \"tooltip\": \"Borg is starting up...\"}"
    exit 0
fi

BYTES=$(echo "$STATS" | $JQ -r '.bytes // 0')
TOTAL=$(echo "$STATS" | $JQ -r '.totalBytes // 0')
SPEED_RAW=$(echo "$STATS" | $JQ -r '.speed // 0')
SPEED=$(echo "$SPEED_RAW" | awk '{printf "%.1f KB/s", $1/1024}')

FILE=$(echo "$STATS" | $JQ -r '.transferring[0].name // "Syncing"')
DONE_FILES=$(echo "$STATS" | $JQ -r '.transfers // 0')
TOTAL_FILES=$(echo "$STATS" | $JQ -r '.totalTransfers // 0')

if [[ "$TOTAL" -gt 0 ]]; then
    PERCENT=$(( 100 * BYTES / TOTAL ))
    BYTES_LEFT=$(( TOTAL - BYTES ))
    MB_LEFT=$(echo "$BYTES_LEFT" | awk '{printf "%.1f MB", $1/1024/1024}')
else
    PERCENT=0
    MB_LEFT="Calculating..."
fi

if [[ "$PERCENT" -eq 0 && $(echo "$SPEED_RAW > 0" | bc -l) -eq 1 ]]; then
    TEXT="   Sync"
else
    TEXT="   ${PERCENT}%"
fi

# The Fix: Use -c to force a single line output so Waybar doesn't crash
$JQ -n -c \
  --arg txt "$TEXT" \
  --arg p "$PERCENT" \
  --arg r "$MB_LEFT" \
  --arg df "$DONE_FILES" \
  --arg tf "$TOTAL_FILES" \
  --arg f "$FILE" \
  --arg s "$SPEED" \
  '{text: $txt, tooltip: "Total Progress: \($p)%\nRemaining: \($r)\nFiles: \($df)/\($tf)\nActive: \($f)\nSpeed: \($s)"}'
