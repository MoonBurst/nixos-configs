#!/usr/bin/env bash

CPU_TEMP=$(sensors | awk '
    /^Tctl/ {
        gsub(/[+°C]/, "");
        for (i=1; i<=NF; i++) {
            if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
        gsub(/\..*/, "", $i);
                print $i;
                exit;
            }
        }
    }')

GPU_TEMP=$(sensors | awk '/^edge/ {gsub(/\+/,""); gsub(/\..*/,"",$2); print $2}' | head -n1)

# --- Define Base System Colors ---
BASE_NA="#d8dee9"
BASE_CRIT="#bf616a"
BASE_WARN="#ebcb8b"
BASE_NORM="#a3be8c"

case $CPU_TEMP in
    "N/A") BASE_COLOR=$BASE_NA && CPU_ICON="   ?" ;;
    [7-9][6-9]|[8-9][0-9]|100) BASE_COLOR=$BASE_CRIT && CPU_ICON="" ;;  # Greater than 75
    [6][6-9]|7[0-5]) BASE_COLOR=$BASE_WARN && CPU_ICON="  " ;;            # Between 66 and 75
    *) BASE_COLOR=$BASE_NORM && CPU_ICON="  " ;;                          # 65 or below
esac

case $GPU_TEMP in
    "N/A") GPU_ICON="   ?" ;;
    [7-9][1-9]|[8-9][0-9]|100) GPU_ICON="" ;;  # Greater than 71
    [5][1-9]|70) GPU_ICON="  " ;;                # Between 51 and 70
    *) GPU_ICON="  " ;;                          # 50 or below
esac

# --- Micro-Shift Engine (Anti-Burn-In) ---
# Extracts the raw HEX channels, adds a minute-based tiny variable offset,
# and compiles a micro-mutated color string to disrupt panel polarization memory.
CURRENT_MIN=$(date +%M)
OFFSET_DEC=$(( 10#$CURRENT_MIN / 4 )) # Generates an offset variance from 0 to 15

# Clean the hash and break down hex channels
HEX_CLEAN="${BASE_COLOR#\#}"
R_HEX="${HEX_CLEAN:0:2}"
G_HEX="${HEX_CLEAN:2:2}"
B_HEX="${HEX_CLEAN:4:2}"

# Convert hex to decimal numbers
R_DEC=$((16#$R_HEX))
G_DEC=$((16#$G_HEX))
B_DEC=$((16#$B_HEX))

# Alternate which specific sub-pixels fluctuate depending on if the minute is odd or even
if [ $((10#$CURRENT_MIN % 2)) -eq 0 ]; then
    R_MUTATED=$(( R_DEC + OFFSET_DEC ))
    G_MUTATED=$(( G_DEC - OFFSET_DEC ))
    B_MUTATED=$(( B_DEC + OFFSET_DEC ))
else
    R_MUTATED=$(( R_DEC - OFFSET_DEC ))
    G_MUTATED=$(( G_MUTATED_VAL=G_DEC + OFFSET_DEC ))
    B_MUTATED=$(( B_DEC - OFFSET_DEC ))
fi

# Boundaries protection (Keeps values strictly within valid 0-255 bounds)
[ $R_MUTATED -gt 255 ] && R_MUTATED=255; [ $R_MUTATED -lt 0 ] && R_MUTATED=0
[ $G_MUTATED -gt 255 ] && G_MUTATED=255; [ $G_MUTATED -lt 0 ] && G_MUTATED=0
[ $B_MUTATED -gt 255 ] && B_MUTATED=255; [ $B_MUTATED -lt 0 ] && B_MUTATED=0

# Format back to an active Waybar Pango-ready hex string
MUTATED_COLOR=$(printf "#%02x%02x%02x" $R_MUTATED $G_MUTATED $B_MUTATED)

# --- Final Pango Output ---
# Wraps the icon and temperature payload in the dynamically micro-shifting color code.
echo "<span color=\"$MUTATED_COLOR\">$GPU_ICON $GPU_TEMP°C $CPU_ICON $CPU_TEMP°C</span>"
