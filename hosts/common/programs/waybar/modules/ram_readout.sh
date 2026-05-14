#!/usr/bin/env bash
set -euo pipefail

RED_THRESHOLD=8
WARN_THRESHOLD=16
COLOR_CRITICAL="#FF0000"
COLOR_WARNING="#FFA500"
COLOR_SUFFICIENT="#00FF00"

# --- Micro-Shift Transformation Engine ---
# Extracts the raw RGB HEX channels and modifies them smoothly by an offset
# between 0 and 15 depending on the minute to break static polarization memory.
shift_color() {
    local target_color=$1
    local current_min=$(date +%M)
    local offset_dec=$(( 10#$current_min / 4 )) # Variance ranges from 0 to 15

    local hex_clean="${target_color#\#}"
    local r_hex="${hex_clean:0:2}"
    local g_hex="${hex_clean:2:2}"
    local b_hex="${hex_clean:4:2}"

    local r_dec=$((16#$r_hex))
    local g_dec=$((16#$g_hex))
    local b_dec=$((16#$b_hex))

    local r_mutated g_mutated b_mutated
    if [ $((10#$current_min % 2)) -eq 0 ]; then
        r_mutated=$(( r_dec + offset_dec ))
        g_mutated=$(( g_dec - offset_dec ))
        b_mutated=$(( b_dec + offset_dec ))
    else
        r_mutated=$(( r_dec - offset_dec ))
        g_mutated=$(( g_dec + offset_dec ))
        b_mutated=$(( b_dec - offset_dec ))
    fi

    # Hardware limits boundary verification
    [ $r_mutated -gt 255 ] && r_mutated=255; [ $r_mutated -lt 0 ] && r_mutated=0
    [ $g_mutated -gt 255 ] && g_mutated=255; [ $g_mutated -lt 0 ] && g_mutated=0
    [ $b_mutated -gt 255 ] && b_mutated=255; [ $b_mutated -lt 0 ] && b_mutated=0

    printf "#%02x%02x%02x" $r_mutated $g_mutated $b_mutated
}

# 1. Get available memory
available_memory=$(free -g | awk '/Mem/ {print $7}')

# 2. Determine Color
color="$COLOR_SUFFICIENT"
if (( available_memory < RED_THRESHOLD )); then
    color="$COLOR_CRITICAL"
elif (( available_memory < WARN_THRESHOLD )); then
    color="$COLOR_WARNING"
fi

# Apply the hardware micro-shift to the resolved threshold color
shifted_color=$(shift_color "$color")

# 3. Get TOP 10 processes using a single AWK command
tooltip=$(ps -eo rss,comm --no-headers | awk '{mag[$2]+=$1} END {for (i in mag) print mag[i], i}' | sort -rn | awk 'NR<=10 {printf "%7d MB  %s\\n", $1/1024, $2}' | tr -d '\n')

# 4. Final Output (Safely passing the micro-shifted color into the JSON object)
echo "{\"text\": \"<span foreground='$shifted_color'>RAM: $available_memory GiB</span>\", \"tooltip\": \"<tt>$tooltip</tt>\"}"
