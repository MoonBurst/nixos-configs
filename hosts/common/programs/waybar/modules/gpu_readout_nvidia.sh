#!/bin/bash
# This script uses the most robust method (query all, then filter by BDF) and handles N/A values gracefully.

# --- Configuration ---
NVIDIA_SMI="/usr/bin/nvidia-smi" # Default path, verify on your system

# Define the target GPU using its PCI Bus ID (BDF).
TARGET_GPU_BUS_ID="26:00.0" 

# NVIDIA-SMI query fields corresponding to the original metrics:
# NOTE: We include 'pci.bus_id' first so we can filter later.
NVIDIA_QUERY_FIELDS="pci.bus_id,temperature.gpu,utilization.gpu,power.draw,memory.total,memory.used"
NVIDIA_FORMAT="csv,noheader,nounits" # Output as CSV, no header, no units

# --- Threshold Definitions ---
TEMP_WARNING=76.0
TEMP_CRITICAL=90.0
UTIL_WARNING=50
UTIL_CRITICAL=80
POWER_WARNING=150.0
POWER_CRITICAL=300.0
VRAM_MIN_WARNING_GB=12.0
VRAM_MIN_CRITICAL_GB=6.0

# --- Color Definitions (Pango Markup Hex Codes) ---
COLOR_CRITICAL="#ff0000"
COLOR_WARNING="#ffa500"
COLOR_DEFAULT="#00FF00"
COLOR_PADDING="#262626"
SEP=" "

# Map level integer (0, 1, 2) to color string for easy lookup
declare -A LEVEL_TO_COLOR
LEVEL_TO_COLOR[0]=$COLOR_DEFAULT
LEVEL_TO_COLOR[1]=$COLOR_WARNING
LEVEL_TO_COLOR[2]=$COLOR_CRITICAL

# --- Helper Function for Coloring/Padding ---
# Handles numeric formatting (e.g., %.0f) and prepends padding zeros in the background color
colorize_output() {
    local value=$1
    local unit=$2
    local color=$3
    local display_format=$4 
    local min_width=$5

    local formatted_value
    # Use printf for formatting the numeric value
    formatted_value=$(echo "$value" | awk '{printf "'"$display_format"'\n", $1}')
    
    local integer_part=${formatted_value%%.*}
    local current_len=${#integer_part}
    local padding=""
    
    if [ "$min_width" -gt "$current_len" ]; then
        local zeros_to_add=$((min_width - current_len))
        for ((i=0; i<zeros_to_add; i++)); do
            padding="${padding}0"
        done
        padding="<span foreground='$COLOR_PADDING'>$padding</span>"
    fi

    printf "%s<span foreground='%s'>%s%s</span>" "$padding" "$color" "$formatted_value" "$unit"
}

# --- Main Logic (FIXED: Filter Output and Gracefully Handle N/A) ---

# 1. GET METRICS: Query ALL GPUs for their BDF + metrics, then filter for the target BDF.
if ! NVIDIA_OUTPUT=$($NVIDIA_SMI --query-gpu="$NVIDIA_QUERY_FIELDS" \
    --format="$NVIDIA_FORMAT" 2>&1 | \
    grep -E "$TARGET_GPU_BUS_ID" | \
    cut -d, -f2- | \
    tr -d '\r' | head -n 1); then
    
    DISPLAY_TEXT=$(printf "<span foreground='%s'>NVIDIA-SMI Error (Query Failed)</span>" "$COLOR_CRITICAL")
    echo "{\"text\": \"$DISPLAY_TEXT\", \"class\": \"critical\"}"
    exit 1
fi

# 2. Single-Pass Extraction using CSV read
# Read the single line CSV output: Temp, Util, Power, VRAM_TOTAL_MIB, VRAM_USED_MIB
IFS=',' read -r FINAL_TEMP UTIL POWER VRAM_TOTAL_MIB VRAM_USED_MIB <<< "$NVIDIA_OUTPUT"

# Remove any leading/trailing whitespace from the extracted values
FINAL_TEMP=$(echo $FINAL_TEMP | xargs)
UTIL=$(echo $UTIL | xargs)
POWER=$(echo $POWER | xargs)
VRAM_TOTAL_MIB=$(echo $VRAM_TOTAL_MIB | xargs)
VRAM_USED_MIB=$(echo $VRAM_USED_MIB | xargs)

# 3. CRITICAL HEALTH CHECK: Check only Temperature (most reliable metric)
if [[ "$FINAL_TEMP" =~ "N/A" ]] || [[ -z "$FINAL_TEMP" ]] ; then
    # If the card is completely inaccessible, display a critical error
    DISPLAY_TEXT=$(printf "<span foreground='%s'>%s N/A (Card Unresponsive)</span>" "$COLOR_CRITICAL" "$TARGET_GPU_BUS_ID")
    echo "{\"text\": \"$DISPLAY_TEXT\", \"class\": \"critical\"}"
    exit 0
fi

# --- Prepare Values for Display and Coloring (Handle N/A Gracefully) ---

# Set values for coloring/threshold checks. Use 0 if the actual metric is N/A/empty.
TEMP_FOR_COLORING=$FINAL_TEMP

if [[ "$UTIL" =~ "N/A" ]] || [[ -z "$UTIL" ]]; then
    UTIL_FOR_COLORING=0
    UTIL_DISPLAY_VALUE="N/A"
else
    UTIL_FOR_COLORING=$UTIL
    UTIL_DISPLAY_VALUE=$(printf "%.0f" "$UTIL_FOR_COLORING")
fi

if [[ "$POWER" =~ "N/A" ]] || [[ -z "$POWER" ]]; then
    POWER_FOR_COLORING=0
    POWER_DISPLAY_VALUE="N/A"
else
    POWER_FOR_COLORING=$POWER
    POWER_DISPLAY_VALUE=$(printf "%.0f" "$POWER_FOR_COLORING")
fi

# --- Determine Levels and Colorize ---
HIGHEST_LEVEL=0
MIB_PER_GB=1024 

# 1. TEMPERATURE 
TEMP_LEVEL=0
TEMP_COLOR=$COLOR_DEFAULT
if (( $(echo "$TEMP_FOR_COLORING >= $TEMP_CRITICAL" | bc -l) )); then
    TEMP_COLOR=$COLOR_CRITICAL; TEMP_LEVEL=2
elif (( $(echo "$TEMP_FOR_COLORING >= $TEMP_WARNING" | bc -l) )); then
    TEMP_COLOR=$COLOR_WARNING; TEMP_LEVEL=1
fi
COLORED_TEMP=$(colorize_output "$TEMP_FOR_COLORING" "°C" "$TEMP_COLOR" "%.0f" 3)
if [ "$TEMP_LEVEL" -gt $HIGHEST_LEVEL ]; then HIGHEST_LEVEL=$TEMP_LEVEL; fi

# 2. UTILIZATION
UTIL_LEVEL=0
UTIL_COLOR=$COLOR_DEFAULT
if [ "$UTIL_FOR_COLORING" -ge "$UTIL_CRITICAL" ]; then
    UTIL_COLOR=$COLOR_CRITICAL; UTIL_LEVEL=2
elif [ "$UTIL_FOR_COLORING" -ge "$UTIL_WARNING" ]; then
    UTIL_COLOR=$COLOR_WARNING; UTIL_LEVEL=1
fi

if [ "$UTIL_DISPLAY_VALUE" = "N/A" ]; then
    # Manually format N/A to match padding (3 chars wide)
    COLORED_UTIL=$(printf "<span foreground='%s'>N/A</span><span foreground='%s'>%%</span>" "$COLOR_PADDING" "$UTIL_COLOR")
else
    COLORED_UTIL=$(colorize_output "$UTIL_FOR_COLORING" "%" "$UTIL_COLOR" "%.0f" 3)
fi
if [ "$UTIL_LEVEL" -gt $HIGHEST_LEVEL ]; then HIGHEST_LEVEL=$UTIL_LEVEL; fi

# 3. POWER 
POWER_LEVEL=0
POWER_COLOR=$COLOR_DEFAULT
if (( $(echo "$POWER_FOR_COLORING >= $POWER_CRITICAL" | bc -l) )); then
    POWER_COLOR=$COLOR_CRITICAL; POWER_LEVEL=2
elif (( $(echo "$POWER_FOR_COLORING >= $POWER_WARNING" | bc -l) )); then
    POWER_COLOR=$COLOR_WARNING; POWER_LEVEL=1
fi

if [ "$POWER_DISPLAY_VALUE" = "N/A" ]; then
    COLORED_POWER=$(printf "<span foreground='%s'>N/A</span><span foreground='%s'>W</span>" "$COLOR_PADDING" "$POWER_COLOR")
else
    COLORED_POWER=$(colorize_output "$POWER_FOR_COLORING" "W" "$POWER_COLOR" "%.0f" 3)
fi
if [ "$POWER_LEVEL" -gt $HIGHEST_LEVEL ]; then HIGHEST_LEVEL=$POWER_LEVEL; fi

# 4. VRAM 
VRAM_LEVEL=0
VRAM_COLOR=$COLOR_DEFAULT
VRAM_MIN_WIDTH=2
COLORED_VRAM_PREFIX=$(printf "<span foreground='%s'>VRAM: </span>" "$COLOR_DEFAULT")

if [ "$VRAM_TOTAL_MIB" != "0" ] && [ "$VRAM_TOTAL_MIB" != "" ]; then
    VRAM_REMAINING_MIB=$(echo "$VRAM_TOTAL_MIB - $VRAM_USED_MIB" | bc)
    VRAM_REMAINING_GB=$(echo "scale=0; $VRAM_REMAINING_MIB / $MIB_PER_GB" | bc -l)

    if (( $(echo "$VRAM_REMAINING_GB <= $VRAM_MIN_CRITICAL_GB" | bc -l) )); then
        VRAM_COLOR=$COLOR_CRITICAL; VRAM_LEVEL=2
    elif (( $(echo "$VRAM_REMAINING_GB <= $VRAM_MIN_WARNING_GB" | bc -l) )); then
        VRAM_COLOR=$COLOR_WARNING; VRAM_LEVEL=1
    fi
    
    VRAM_DISPLAY_TEXT=$(colorize_output "$VRAM_REMAINING_GB" "GiB" "$VRAM_COLOR" "%.0f" $VRAM_MIN_WIDTH)
    COLORED_VRAM="${COLORED_VRAM_PREFIX}${VRAM_DISPLAY_TEXT}"

else
    COLORED_VRAM=$(printf "%s<span foreground='%s'>N/AGiB</span>" \
        "$COLORED_VRAM_PREFIX" \
        "$COLOR_DEFAULT")
fi

if [ "$VRAM_LEVEL" -gt $HIGHEST_LEVEL ]; then HIGHEST_LEVEL=$VRAM_LEVEL; fi

# --- Final JSON Output ---
GPU_PREFIX_COLOR=${LEVEL_TO_COLOR[$HIGHEST_LEVEL]}
COLORED_GPU_PREFIX=$(printf "<span foreground='%s'>GPU </span>" "$GPU_PREFIX_COLOR")

DISPLAY_TEXT=$(printf "%s%s%s%s%s%s%s%s" \
    "$COLORED_GPU_PREFIX" \
    "$COLORED_TEMP" \
    "$SEP" \
    "$COLORED_UTIL" \
    "$SEP" \
    "$COLORED_POWER" \
    "$SEP" \
    "$COLORED_VRAM")

printf '%s  %s\n' "$DISPLAY_TEXT" ""
