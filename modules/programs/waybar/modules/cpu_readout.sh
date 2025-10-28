#!/usr/bin/env bash
set -euo pipefail

# This script continuously monitors CPU temperature and usage,
# formatting the output as Pango markup for use in status bars (like Polybar/i3status).

# --- Configuration ---
CRIT="#f53c3c" # Red
WARN="#ffa500" # Orange
NORM="#00FF00" # Green
PAD="#262626" # Padding color (Dark Gray) Used to make text invisible on grey background

# Thresholds for temperature (°C)
T_WARN=65
T_CRIT=70

# Thresholds for usage (%)
U_WARN=50
U_CRIT=80

monitor_cpu() {
    # --- CPU Temp and Usage Readout ---
    
    # 1. Get Temperature: Extracts Tctl from k10temp, rounds to nearest integer, suppresses errors.
    # Note: 'sensors' may print to stderr on certain hardware, which breaks the Waybar stream.
    temp_c=$(sensors 2>/dev/null | awk '/Tctl/{print int($2 + 0.5); exit}' 2>/dev/null)

    # 2. Get Usage: Uses top to get CPU usage (100 - idle time), rounds to integer, suppresses errors.
    # Note: 'top' may also print to stderr if there are issues.
    cpu_u=$(top -bn1 2>/dev/null | awk '/%Cpu/ {print int(100 - $8)}' 2>/dev/null)

    # Provide default values if reading failed to prevent unbound variable errors later
    temp_c=${temp_c:-0}
    cpu_u=${cpu_u:-0}


    # --- AWK Final Formatting ---
    AWK_VARS="-v TC=$temp_c -v UC=$cpu_u -v CRIT=$CRIT -v WARN=$WARN -v NORM=$NORM -v PAD=$PAD -v T_WARN=$T_WARN -v T_CRIT=$T_CRIT -v U_WARN=$U_WARN -v U_CRIT=$U_CRIT"

    FINAL_OUTPUT=$(awk $AWK_VARS '
        BEGIN {
            
            # --- 1. Determine Component Colors ---
            
            # Temperature Color
            T_COLOR = (TC >= T_CRIT) ? CRIT : (TC >= T_WARN) ? WARN : NORM
            # Ensure T_VAL is formatted even if it was 0 from the default
            T_VAL = (TC == 0) ? "N/A" : TC "°C"
            if (TC != 0) {
                 # Pad the temperature value for a fixed width (e.g., 3 digits: " 65", "100")
                 T_VAL_FORMATTED = sprintf("%3d", TC)
                 # Replaces leading spaces with the span of the PAD color
                 gsub(/ /, "<span color=\"" PAD "\"> </span>", T_VAL_FORMATTED)
                 T_VAL = T_VAL_FORMATTED "°C"
            }


            # Usage Color
            U_COLOR = (UC >= U_CRIT) ? CRIT : (UC >= U_WARN) ? WARN : NORM
            
            # Format usage value with leading zero/padding text for fixed width (3 digits: "05%", "50%", "100%")
            U_VAL_FORMATTED = sprintf("%03d", UC)

            # Replaces leading "0"s with a span of the PAD color (for visual padding effect).
            # The "&" ensures the matched character (the "0"s) is preserved inside the new span.
            # FIX: Corrected AWK syntax for the replacement string. The whole string must be quoted.
            sub(/^0*/, "<span color=\"" PAD "\">" "&" "</span>", U_VAL_FORMATTED)
            U_VAL = U_VAL_FORMATTED "%"


            # --- 2. Determine Overall (Label) Color ---
            # Convert colors back to a numerical severity level for comparison (3=CRIT, 2=WARN, 1=NORM)
            T_SEVERITY = (T_COLOR == CRIT) ? 3 : (T_COLOR == WARN) ? 2 : 1
            U_SEVERITY = (U_COLOR == CRIT) ? 3 : (U_COLOR == WARN) ? 2 : 1
            
            # Get the highest severity level
            MAX_SEVERITY = (T_SEVERITY > U_SEVERITY) ? T_SEVERITY : U_SEVERITY
            
            # Convert highest severity back to hex color for the "CPU:" label
            LABEL_COLOR = (MAX_SEVERITY == 3) ? CRIT : (MAX_SEVERITY == 2) ? WARN : NORM


            # --- 3. Print Final Output (Pango Markup) ---
            print "<span color=\"" LABEL_COLOR "\">CPU:</span>" \
                  " <span color=\"" T_COLOR "\">" T_VAL "</span>" \
                  " <span color=\"" U_COLOR "\">" U_VAL "</span>"
        }
    ')

    echo "$FINAL_OUTPUT"
}

# --- Main Execution Loop (Required for Waybar interval: 0 streaming) ---
while true; do
    monitor_cpu
    sleep 1
done
