#!/usr/bin/env bash
set -euo pipefail

RED_THRESHOLD=8
WARN_THRESHOLD=16
COLOR_CRITICAL="#FF0000"
COLOR_WARNING="#FFA500"
COLOR_SUFFICIENT="#00FF00"

# 1. Get available memory
available_memory=$(free -g | awk '/Mem/ {print $7}')

# 2. Determine Color
color="$COLOR_SUFFICIENT"
if (( available_memory < RED_THRESHOLD )); then
    color="$COLOR_CRITICAL"
elif (( available_memory < WARN_THRESHOLD )); then
    color="$COLOR_WARNING"
fi

# 3. Get TOP 10 processes using a single AWK command
# This avoids pipe issues by doing the 'head' logic inside AWK itself
tooltip=$(ps -eo rss,comm --no-headers | awk '{mag[$2]+=$1} END {for (i in mag) print mag[i], i}' | sort -rn | awk 'NR<=10 {printf "%7d MB  %s\\n", $1/1024, $2}' | tr -d '\n')

# 4. Final Output
echo "{\"text\": \"<span foreground='$color'>RAM: $available_memory GiB</span>\", \"tooltip\": \"<tt>$tooltip</tt>\"}"
