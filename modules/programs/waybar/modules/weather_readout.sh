#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# This script fetches weather data from OpenWeatherMap, applies temperature-based
# color thresholds, and outputs the result in JSON format for status bars (like Waybar).

# ==========================================================
#                CONFIGURATION
# ==========================================================
CITY="Houston"
API_KEY="340c6f5eecff61ffd342313e4f2a7547"

# Define Pango Markup Color Tags (Waybar Compatible)
GREEN_TAG="<span foreground='#33FF33'>%s</span>"  # Green (<= 76°F)
YELLOW_TAG="<span foreground='yellow'>%s</span>"   # Yellow (77°F to 85°F)
RED_TAG="<span foreground='#FF0000'>%s</span>"     # Bright Red (>= 86°F)
# ==========================================================

monitor_weather() {
    # --- Fetch and Validate Weather Data ---
    local weather
    local URL="https://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$API_KEY"

    # Fetch weather data. Use a subshell to capture the exit status.
    # The '|| echo "CURL_ERROR"' ensures that 'set -e' doesn't kill the script if curl fails.
    weather=$(curl -s "$URL" || echo "CURL_ERROR")

    # Check for network/curl error
    if [ "$weather" = "CURL_ERROR" ]; then
        # Minimal error output for stability
        echo "NET ERR"
        return
    fi
    
    # Validate that we got a JSON response containing the main temp field.
    if ! echo "$weather" | jq -e '.main.temp' >/dev/null; then
        # Minimal error output for stability
        echo "API ERR"
        return
    fi

    # --- Process Temperature ---
    local temp rounded_temp temp_fahrenheit
    temp=$(echo "$weather" | jq -r '.main.temp') # Temp is in Kelvin

    # Calculate temp in Fahrenheit (to two decimal places) using awk/bc.
    temp_fahrenheit=$(awk -v temp=$temp 'BEGIN{ printf("%.2f\n", ((temp - 273.15) * 9/5) + 32) }')

    # Round the temperature to the nearest whole number for the main display text
    rounded_temp=$(awk -v temp="$temp_fahrenheit" 'BEGIN{ printf "%.0f\n", temp }')

    # --- Determine Color Tag ---
	local COLOR_FORMAT="%s" # Use a default format without any color
	# Thresholds are based on the rounded temperature. 
	if (( rounded_temp >= 86 )); then
		COLOR_FORMAT=$RED_TAG
	elif (( rounded_temp >= 77 )); then
		COLOR_FORMAT=$YELLOW_TAG
	elif (( rounded_temp <= 76 )); then
		COLOR_FORMAT=$GREEN_TAG
	fi

    # --- Output Result in RAW Pango Markup ---
    # Output ONLY the colored Pango markup temperature string.
   printf "${COLOR_FORMAT}\n" "${rounded_temp}°F"
}
# --- Main Execution Loop (Required for Waybar interval: 0 streaming) ---
while true; do
    monitor_weather
    sleep 300
done
