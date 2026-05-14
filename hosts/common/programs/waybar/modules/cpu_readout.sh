#!/usr/bin/env bash
set -euo pipefail

# This script monitors CPU temperature and usage with micro-shifts
# applied to colors to disrupt static pixel states.

# --- Configuration ---
CRIT="#f53c3c" # Red
WARN="#ffa500" # Orange
PAD="#262626"  # Padding color

# Thresholds for temperature (°C)
T_WARN=65
T_CRIT=70

# Thresholds for usage (%)
U_WARN=50
U_CRIT=80

monitor_cpu() {
    # --- Micro-Shift Color Calculation ---
    # We use the current minute to slightly wiggle the R and B channels of #00FF00.
    # This keeps the color visually "Green" but changes the hardware sub-pixel values.
    CURRENT_MIN=$(date +%M)

    # Generate a shifting hex value between 00 and 1E (0 to 30 out of 255)
    OFFSET_VAL=$(( 10#$CURRENT_MIN / 2 )) # Changes slightly every 2 minutes
    HEX_OFFSET=$(printf "%02x" $OFFSET_VAL)

    # NORM shifts smoothly between #00FF00, #1EFF00, #00FF1E, and #1EFF1E
    if [ $((10#$CURRENT_MIN % 2)) -eq 0 ]; then
        NORM="#${HEX_OFFSET}ff00"
    else
        NORM="#00ff${HEX_OFFSET}"
    fi

    # --- CPU Temp and Usage Readout ---
    temp_c=$(sensors 2>/dev/null | awk '/Tctl/{print int($2 + 0.5); exit}' 2>/dev/null)
    cpu_u=$(top -bn1 2>/dev/null | awk '/%Cpu/ {print int(100 - $8)}' 2>/dev/null)

    temp_c=${temp_c:-0}
    cpu_u=${cpu_u:-0}

    # --- AWK Final Formatting ---
    AWK_VARS="-v TC=$temp_c -v UC=$cpu_u -v CRIT=$CRIT -v WARN=$WARN -v NORM=$NORM -v PAD=$PAD -v T_WARN=$T_WARN -v T_CRIT=$T_CRIT -v U_WARN=$U_WARN -v U_CRIT=$U_CRIT"

    FINAL_OUTPUT=$(awk $AWK_VARS '
        BEGIN {
            # --- 1. Determine Component Colors ---
            T_COLOR = (TC >= T_CRIT) ? CRIT : (TC >= T_WARN) ? WARN : NORM
            T_VAL = (TC == 0) ? "N/A" : TC "°C"
            if (TC != 0) {
                 T_VAL_FORMATTED = sprintf("%3d", TC)
                 gsub(/ /, "<span color=\"" PAD "\"> </span>", T_VAL_FORMATTED)
                 T_VAL = T_VAL_FORMATTED "°C"
            }

            U_COLOR = (UC >= U_CRIT) ? CRIT : (UC >= U_WARN) ? WARN : NORM
            U_VAL_FORMATTED = sprintf("%03d", UC)
            sub(/^0*/, "<span color=\"" PAD "\">" "&" "</span>", U_VAL_FORMATTED)
            U_VAL = U_VAL_FORMATTED "%"

            # --- 2. Determine Overall (Label) Color ---
            T_SEVERITY = (T_COLOR == CRIT) ? 3 : (T_COLOR == WARN) ? 2 : 1
            U_SEVERITY = (U_COLOR == CRIT) ? 3 : (U_COLOR == WARN) ? 2 : 1
            MAX_SEVERITY = (T_SEVERITY > U_SEVERITY) ? T_SEVERITY : U_SEVERITY
            LABEL_COLOR = (MAX_SEVERITY == 3) ? CRIT : (MAX_SEVERITY == 2) ? WARN : NORM

            # --- 3. Print Final Output ---
            print "<span color=\"" LABEL_COLOR "\">CPU:</span>" \
                  " <span color=\"" T_COLOR "\">" T_VAL "</span>" \
                  " <span color=\"" U_COLOR "\">" U_VAL "</span>"
        }
    ')

    echo "$FINAL_OUTPUT"
}

monitor_cpu
