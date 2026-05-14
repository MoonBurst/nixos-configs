#!/usr/bin/env bash

# Enable strict mode: exit on error (-e), exit on unbound variables (-u),
# set last exit code of pipeline to non-zero if any command fails (-o pipefail).
set -euo pipefail

# This script monitors AMD GPU statistics (Temp, Power, Usage, VRAM) via rocm-smi
# and formats the output as Pango markup with micro-shifting pixel defense.

# --- Threshold Definitions (Warning, Critical) ---
TEMP_WARNING="76,90" # Temperature (°C)
UTIL_WARNING="50,80" # GPU Use (%)
POWER_WARNING="150,300" # Power (W)
VRAM_MAX_WARNING_PCT="50,75" # VRAM by % used

# --- Constants and Setup ---
COLOR_CRITICAL="#ff0000"
COLOR_WARNING="#ffa500"
COLOR_DEFAULT="#00FF00"
COLOR_PADDING="#262626"
DEVICE_ID=$1
BYTES_PER_GIB=1073741824

# --- Threshold Array Initialization ---
IFS=',' read -r -a TEMP_THRESH <<< "$TEMP_WARNING"
IFS=',' read -r -a POWER_THRESH <<< "$POWER_WARNING"
IFS=',' read -r -a UTIL_THRESH <<< "$UTIL_WARNING"
IFS=',' read -r -a VRAM_THRESH <<< "$VRAM_MAX_WARNING_PCT"
IFS=$' \t\n' # Reset IFS

# --- Micro-Shift Engine ---
# Gently shifts RGB color channels by a microscopic decimal value (0 to 15)
# based on the system minute to break up static liquid crystal memory.
shift_color() {
    local target_color=$1
    local current_min=$(date +%M)
    local offset_dec=$(( 10#$current_min / 4 )) # Restricts range safely from 0 to 15

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

    # Hardware clip boundaries protection
    [ $r_mutated -gt 255 ] && r_mutated=255; [ $r_mutated -lt 0 ] && r_mutated=0
    [ $g_mutated -gt 255 ] && g_mutated=255; [ $g_mutated -lt 0 ] && g_mutated=0
    [ $b_mutated -gt 255 ] && b_mutated=255; [ $b_mutated -lt 0 ] && b_mutated=0

    printf "#%02x%02x%02x" $r_mutated $g_mutated $b_mutated
}

# --- Utility Function (Single Color Check with Integrated Shifting) ---
determine_color() {
    local value=$1; local warn=$2; local crit=$3
    local color_code="$COLOR_DEFAULT"
    if (( $(echo "$value > $crit" | bc -l) )); then
        color_code="$COLOR_CRITICAL"
    elif (( $(echo "$value > $warn" | bc -l) )); then
        color_code="$COLOR_WARNING"
    fi
    # Instantly output the hardware-mutated hex string
    shift_color "$color_code"
}

# --- Utility Function (Padding) ---
get_pad() {
    local val=$1; local len=${#val}; local target=$2
    local shifted_padding=$(shift_color "$COLOR_PADDING")
    if [ "$len" -lt "$target" ]; then
        printf "<span foreground=\"$shifted_padding\">%0*d</span>" $((target - len)) 0
    fi
}

# --- Input Validation (Run once before loop) ---
if [ -z "$DEVICE_ID" ] || ([ "$DEVICE_ID" != "0" ] && [ "$DEVICE_ID" != "1" ]); then
    echo "Error: Invalid or missing device ID. Must be 0 or 1." >&2
    exit 1
fi

# --- Main Monitoring Function ---
monitor_gpu() {
    # --- Primary ROCM-SMI Call & Extraction ---
    local ROCM_OUTPUT
    ROCM_OUTPUT=$(rocm-smi -d "$DEVICE_ID" -a --showmeminfo VRAM 2>/dev/null || :)

    if [ -z "$ROCM_OUTPUT" ]; then
        local shifted_err_padding=$(shift_color "$COLOR_PADDING")
        echo "<span foreground=\"$shifted_err_padding\">GPU $DEVICE_ID N/A</span>"
        return
    fi

    local TEMP_JUNCTION=$(echo "$ROCM_OUTPUT" | grep "Temperature (Sensor junction)" | awk '{print $NF}' | xargs printf "%.0f")
    local POWER_W=$(echo "$ROCM_OUTPUT" | grep "Average Graphics Package Power" | awk '{print $NF}' | xargs printf "%.0f")
    local GPU_USAGE_NUM=$(echo "$ROCM_OUTPUT" | grep "GPU use (%)" | awk '{print $NF}' | tr -cd '0-9')
    local VRAM_TOTAL_BYTES=$(echo "$ROCM_OUTPUT" | grep "VRAM Total Memory (B)" | awk '{print $NF}' | tr -cd '0-9')
    local VRAM_USED_BYTES=$(echo "$ROCM_OUTPUT" | grep "VRAM Total Used Memory (B)" | awk '{print $NF}' | tr -cd '0-9')

    TEMP_JUNCTION=${TEMP_JUNCTION:-0}; POWER_W=${POWER_W:-0}; GPU_USAGE_NUM=${GPU_USAGE_NUM:-0}
    VRAM_TOTAL_BYTES=${VRAM_TOTAL_BYTES:-0}; VRAM_USED_BYTES=${VRAM_USED_BYTES:-0}

    if [ "$TEMP_JUNCTION" -eq 0 ] && [ "$POWER_W" -eq 0 ] && [ "$GPU_USAGE_NUM" -eq 0 ]; then
        local shifted_fail_padding=$(shift_color "$COLOR_PADDING")
        echo "<span foreground=\"$shifted_fail_padding\">GPU $DEVICE_ID N/A (Parse Fail)</span>"
        return
    fi

    # --- VRAM CSV FALLBACK LOGIC ---
    if [ "$VRAM_TOTAL_BYTES" -eq 0 ] || [ "$VRAM_USED_BYTES" -eq 0 ]; then
        local CSV_LINE
        CSV_LINE=$(rocm-smi --showmeminfo VRAM --csv 2>/dev/null | grep "^card$DEVICE_ID," || :)

        if [ -n "$CSV_LINE" ]; then
            local TOTAL_CSV_RAW USED_CSV_RAW
            IFS=',' read -r _ TOTAL_CSV_RAW USED_CSV_RAW <<< "$CSV_LINE"
            local TOTAL_CSV=${TOTAL_CSV_RAW//[^0-9]/}; local USED_CSV=${USED_CSV_RAW//[^0-9]/}

            if [ "$VRAM_TOTAL_BYTES" -eq 0 ] && [ "$TOTAL_CSV" -ne 0 ]; then
                VRAM_TOTAL_BYTES="$TOTAL_CSV"
            fi
            if [ "$VRAM_USED_BYTES" -eq 0 ] && [ "$USED_CSV" -ne 0 ]; then
                VRAM_USED_BYTES="$USED_CSV"
            fi
        fi
    fi

    # --- VRAM Calculation and Formatting ---
    local VRAM_COLOR
    local VRAM_DISPLAY_VALUE="N/A"
    local VRAM_UNIT="GiB"

    if [ "$VRAM_TOTAL_BYTES" -gt 0 ]; then
        local VRAM_REMAINING_BYTES
        VRAM_REMAINING_BYTES=$(echo "$VRAM_TOTAL_BYTES - $VRAM_USED_BYTES" | bc)
        VRAM_DISPLAY_VALUE=$(printf "%.0f" "$(echo "scale=0; $VRAM_REMAINING_BYTES / $BYTES_PER_GIB" | bc)")

        local VRAM_USED_PCT
        VRAM_USED_PCT=$(echo "scale=1; $VRAM_USED_BYTES * 100 / $VRAM_TOTAL_BYTES" | bc)
        VRAM_COLOR=$(determine_color "$VRAM_USED_PCT" "${VRAM_THRESH[0]}" "${VRAM_THRESH[1]}")
    elif [ "$VRAM_USED_BYTES" -gt 0 ]; then
        VRAM_DISPLAY_VALUE=$(printf "%.0f" "$(echo "scale=0; $VRAM_USED_BYTES / $BYTES_PER_GIB" | bc)")
        VRAM_COLOR=$(shift_color "$COLOR_DEFAULT")
        VRAM_UNIT="GiB (Used)"
    else
        VRAM_COLOR=$(shift_color "$COLOR_DEFAULT")
    fi

    # --- Final Coloring and Output ---
    local TEMP_COLOR=$(determine_color "$TEMP_JUNCTION" "${TEMP_THRESH[0]}" "${TEMP_THRESH[1]}")
    local POWER_COLOR=$(determine_color "$POWER_W" "${POWER_THRESH[0]}" "${POWER_THRESH[1]}")
    local UTIL_COLOR=$(determine_color "$GPU_USAGE_NUM" "${UTIL_THRESH[0]}" "${UTIL_THRESH[1]}")

    # Determine Overall Status Color
    local OVERALL_COLOR_RAW="$COLOR_DEFAULT"
    if [[ "$TEMP_COLOR" == "$(shift_color "$COLOR_CRITICAL")" || "$POWER_COLOR" == "$(shift_color "$COLOR_CRITICAL")" || "$VRAM_COLOR" == "$(shift_color "$COLOR_CRITICAL")" || "$UTIL_COLOR" == "$(shift_color "$COLOR_CRITICAL")" ]]; then
        OVERALL_COLOR_RAW="$COLOR_CRITICAL"
    elif [[ "$TEMP_COLOR" == "$(shift_color "$COLOR_WARNING")" || "$POWER_COLOR" == "$(shift_color "$COLOR_WARNING")" || "$VRAM_COLOR" == "$(shift_color "$COLOR_WARNING")" || "$UTIL_COLOR" == "$(shift_color "$COLOR_WARNING")" ]]; then
        OVERALL_COLOR_RAW="$COLOR_WARNING"
    fi
    local OVERALL_COLOR=$(shift_color "$OVERALL_COLOR_RAW")

    # Final output using Pango Markup.
    echo "<span foreground=\"$OVERALL_COLOR\">GPU:</span> \
<span foreground=\"$TEMP_COLOR\">$(get_pad "$TEMP_JUNCTION" 3)$TEMP_JUNCTION°C</span> \
<span foreground=\"$UTIL_COLOR\">$(get_pad "$GPU_USAGE_NUM" 3)$GPU_USAGE_NUM%</span> \
<span foreground=\"$POWER_COLOR\">$(get_pad "$POWER_W" 3)${POWER_W}W</span> \
<span foreground=\"$VRAM_COLOR\">VRAM: $VRAM_DISPLAY_VALUE $VRAM_UNIT</span>"
}

monitor_gpu
