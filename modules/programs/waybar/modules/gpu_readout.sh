#!/usr/bin/env bash

# Enable strict mode: exit on error (-e), exit on unbound variables (-u),
# set last exit code of pipeline to non-zero if any command fails (-o pipefail).
set -euo pipefail

# This script monitors AMD GPU statistics (Temp, Power, Usage, VRAM) via rocm-smi
# and formats the output as Pango markup for continuous display in status bars.

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
# Read comma-separated thresholds into indexed arrays
IFS=',' read -r -a TEMP_THRESH <<< "$TEMP_WARNING"
IFS=',' read -r -a POWER_THRESH <<< "$POWER_WARNING"
IFS=',' read -r -a UTIL_THRESH <<< "$UTIL_WARNING"
IFS=',' read -r -a VRAM_THRESH <<< "$VRAM_MAX_WARNING_PCT"
IFS=$' \t\n' # Reset IFS

# --- Utility Function (Single Color Check) ---
# FIX: Changed to POSIX standard function definition to avoid syntax errors in sh/dash.
determine_color() {
    local value=$1; local warn=$2; local crit=$3
    local color_code="$COLOR_DEFAULT"
    # Logic: If value is GREATER THAN crit/warn, change color. Use 'bc' for floating-point comparison.
    if (( $(echo "$value > $crit" | bc -l) )); then
        color_code="$COLOR_CRITICAL"
    elif (( $(echo "$value > $warn" | bc -l) )); then
        color_code="$COLOR_WARNING"
    fi
    echo "$color_code"
}

# --- Utility Function (Padding) ---
# Generates padding spaces (as zero characters with the padding color)
get_pad() {
    local val=$1; local len=${#val}; local target=$2
    if [ "$len" -lt "$target" ]; then
        printf "<span foreground=\"$COLOR_PADDING\">%0*d</span>" $((target - len)) 0
    fi
}

# --- Input Validation (Run once before loop) ---
if [ -z "$DEVICE_ID" ] || ([ "$DEVICE_ID" != "0" ] && [ "$DEVICE_ID" != "1" ]); then
    echo "Error: Invalid or missing device ID. Must be 0 or 1." >&2
    exit 1
fi

# --- Main Monitoring Function ---
monitor_gpu() {
    # ----------------------------------------------------------------------
    # --- Primary ROCM-SMI Call & Extraction ---
    # ----------------------------------------------------------------------

    # Get all required stats
    local ROCM_OUTPUT
    ROCM_OUTPUT=$(rocm-smi -d "$DEVICE_ID" -a --showmeminfo VRAM 2>/dev/null || :)

    if [ -z "$ROCM_OUTPUT" ]; then
        # On failure, output a gray N/A status and exit this iteration
        # Note: Keeping the device ID here to help the user identify which GPU failed.
        echo "<span foreground=\"$COLOR_PADDING\">GPU $DEVICE_ID N/A</span>"
        return
    fi

    # Extract and sanitize values. xargs printf is used to safely round/clean numbers.
    local TEMP_JUNCTION=$(echo "$ROCM_OUTPUT" | grep "Temperature (Sensor junction)" | awk '{print $NF}' | xargs printf "%.0f")
    local POWER_W=$(echo "$ROCM_OUTPUT" | grep "Average Graphics Package Power" | awk '{print $NF}' | xargs printf "%.0f")
    local GPU_USAGE_NUM=$(echo "$ROCM_OUTPUT" | grep "GPU use (%)" | awk '{print $NF}' | tr -cd '0-9')
    local VRAM_TOTAL_BYTES=$(echo "$ROCM_OUTPUT" | grep "VRAM Total Memory (B)" | awk '{print $NF}' | tr -cd '0-9')
    local VRAM_USED_BYTES=$(echo "$ROCM_OUTPUT" | grep "VRAM Total Used Memory (B)" | awk '{print $NF}' | tr -cd '0-9')

    # Set defaults (condensed logic, 0 if empty)
    TEMP_JUNCTION=${TEMP_JUNCTION:-0}; POWER_W=${POWER_W:-0}; GPU_USAGE_NUM=${GPU_USAGE_NUM:-0}
    VRAM_TOTAL_BYTES=${VRAM_TOTAL_BYTES:-0}; VRAM_USED_BYTES=${VRAM_USED_BYTES:-0}

    # Validation check: if all core metrics are zero, assume failure and exit this loop iteration
    if [ "$TEMP_JUNCTION" -eq 0 ] && [ "$POWER_W" -eq 0 ] && [ "$GPU_USAGE_NUM" -eq 0 ]; then
        echo "<span foreground=\"$COLOR_PADDING\">GPU $DEVICE_ID N/A (Parse Fail)</span>"
        return
    fi

    # ----------------------------------------------------------------------
    # --- VRAM CSV FALLBACK LOGIC ---
    # ----------------------------------------------------------------------
    if [ "$VRAM_TOTAL_BYTES" -eq 0 ] || [ "$VRAM_USED_BYTES" -eq 0 ]; then
        local CSV_LINE
        # FIX: Using '|| :' to suppress the exit status if rocm-smi fails.
        CSV_LINE=$(rocm-smi --showmeminfo VRAM --csv 2>/dev/null | grep "^card$DEVICE_ID," || :)

        if [ -n "$CSV_LINE" ]; then
            local TOTAL_CSV_RAW USED_CSV_RAW
            # Read values from CSV line
            IFS=',' read -r _ TOTAL_CSV_RAW USED_CSV_RAW <<< "$CSV_LINE"
            # Strip non-numeric characters
            local TOTAL_CSV=${TOTAL_CSV_RAW//[^0-9]/}; local USED_CSV=${USED_CSV_RAW//[^0-9]/}

            if [ "$VRAM_TOTAL_BYTES" -eq 0 ] && [ "$TOTAL_CSV" -ne 0 ]; then
                VRAM_TOTAL_BYTES="$TOTAL_CSV"
            fi
            
            if [ "$VRAM_USED_BYTES" -eq 0 ] && [ "$USED_CSV" -ne 0 ]; then
                VRAM_USED_BYTES="$USED_CSV"
            fi
        fi
    fi

    # ----------------------------------------------------------------------
    # --- VRAM Calculation and Formatting ---
    # ----------------------------------------------------------------------

    local VRAM_COLOR="$COLOR_DEFAULT"
    local VRAM_DISPLAY_VALUE="N/A"
    local VRAM_UNIT="GiB"

    if [ "$VRAM_TOTAL_BYTES" -gt 0 ]; then
        local VRAM_REMAINING_BYTES
        VRAM_REMAINING_BYTES=$(echo "$VRAM_TOTAL_BYTES - $VRAM_USED_BYTES" | bc)
        
        # Display Remaining VRAM (GiB, rounded to nearest integer)
        VRAM_DISPLAY_VALUE=$(printf "%.0f" "$(echo "scale=0; $VRAM_REMAINING_BYTES / $BYTES_PER_GIB" | bc)")
        
        # Calculate used percentage for color check
        local VRAM_USED_PCT
        VRAM_USED_PCT=$(echo "scale=1; $VRAM_USED_BYTES * 100 / $VRAM_TOTAL_BYTES" | bc)
        VRAM_COLOR=$(determine_color "$VRAM_USED_PCT" "${VRAM_THRESH[0]}" "${VRAM_THRESH[1]}")

    elif [ "$VRAM_USED_BYTES" -gt 0 ]; then
        # If total is 0 but used is known, display used VRAM (rounded to nearest integer)
        VRAM_DISPLAY_VALUE=$(printf "%.0f" "$(echo "scale=0; $VRAM_USED_BYTES / $BYTES_PER_GIB" | bc)")
        VRAM_COLOR="$COLOR_DEFAULT"
        VRAM_UNIT="GiB (Used)"
    fi

    # ----------------------------------------------------------------------
    # --- Final Coloring and Output ---
    # ----------------------------------------------------------------------

    # Determine colors
    local TEMP_COLOR
    TEMP_COLOR=$(determine_color "$TEMP_JUNCTION" "${TEMP_THRESH[0]}" "${TEMP_THRESH[1]}")
    local POWER_COLOR
    POWER_COLOR=$(determine_color "$POWER_W" "${POWER_THRESH[0]}" "${POWER_THRESH[1]}")
    local UTIL_COLOR
    UTIL_COLOR=$(determine_color "$GPU_USAGE_NUM" "${UTIL_THRESH[0]}" "${UTIL_THRESH[1]}")

    # Determine Overall Status Color
    local OVERALL_COLOR="$COLOR_DEFAULT"
    if [[ "$TEMP_COLOR" == "$COLOR_CRITICAL" || "$POWER_COLOR" == "$COLOR_CRITICAL" || "$VRAM_COLOR" == "$COLOR_CRITICAL" || "$UTIL_COLOR" == "$COLOR_CRITICAL" ]]; then
        OVERALL_COLOR="$COLOR_CRITICAL"
    elif [[ "$TEMP_COLOR" == "$COLOR_WARNING" || "$POWER_COLOR" == "$COLOR_WARNING" || "$VRAM_COLOR" == "$COLOR_WARNING" || "$UTIL_COLOR" == "$COLOR_WARNING" ]]; then
        OVERALL_COLOR="$COLOR_WARNING"
    fi

    # Final output using Pango Markup.
    echo "<span foreground=\"$OVERALL_COLOR\">GPU:</span> \
<span foreground=\"$TEMP_COLOR\">$(get_pad "$TEMP_JUNCTION" 3)$TEMP_JUNCTION°C</span> \
<span foreground=\"$UTIL_COLOR\">$(get_pad "$GPU_USAGE_NUM" 3)$GPU_USAGE_NUM%</span> \
<span foreground=\"$POWER_COLOR\">$(get_pad "$POWER_W" 3)${POWER_W}W</span> \
<span foreground=\"$VRAM_COLOR\">VRAM: $VRAM_DISPLAY_VALUE $VRAM_UNIT</span>"
}
# --- Main Execution Loop (Required for Waybar interval: 0 streaming) ---
while true; do
    monitor_gpu
    sleep 1
done
