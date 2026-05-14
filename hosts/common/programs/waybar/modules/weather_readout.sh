#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# This script fetches current weather and forecast data from OpenWeatherMap,
# applies temperature-based color thresholds, and outputs JSON for Waybar
# with micro-shifting pixel defense to eliminate display retention risk.

# ==========================================================
#                CONFIGURATION
# ==========================================================

CITY=$(cat /run/secrets/weather_city | xargs)
API_KEY=$(cat /run/secrets/weather_api_key | xargs)

# Base Color Targets (Hex values for color shifting engine)
COLOR_GREEN="#33FF33"
COLOR_YELLOW="#FFFF00"
COLOR_RED="#FF0000"

# ==========================================================

# --- Micro-Shift Transformation Engine ---
# Oscillates RGB channels by a tiny value (0 to 15) matching the system clock minute.
# This prevents static liquid crystal memory build-up over long tracking cycles.
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

get_formatted_temp() {
    local temp_k=$1
    local temp_f=$(awk -v temp=$temp_k 'BEGIN{ printf("%.0f", ((temp - 273.15) * 9/5) + 32) }')
    local chosen_color

    if (( temp_f >= 86 )); then
        chosen_color=$(shift_color "$COLOR_RED")
    elif (( temp_f >= 77 )); then
        chosen_color=$(shift_color "$COLOR_YELLOW")
    else
        chosen_color=$(shift_color "$COLOR_GREEN")
    fi

    printf "<span foreground='%s'>%s°F</span>" "$chosen_color" "$temp_f"
}

monitor_weather() {
    # Fetch current weather and forecast
    local current_url="https://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$API_KEY"
    local forecast_url="https://api.openweathermap.org/data/2.5/forecast?q=$CITY&appid=$API_KEY&cnt=6"

    local current=$(curl -s "$current_url" || echo "CURL_ERROR")
    local forecast=$(curl -s "$forecast_url" || echo "CURL_ERROR")

    # Handle errors
    if [[ "$current" = "CURL_ERROR" || "$forecast" = "CURL_ERROR" ]]; then
        echo '{"text":"NET ERR","tooltip":"Network error"}'
        return
    fi

    if ! echo "$current" | jq -e '.main.temp' >/dev/null || ! echo "$forecast" | jq -e '.list' >/dev/null; then
        echo '{"text":"API ERR","tooltip":"API error"}'
        return
    fi

    # Process current temp
    local current_temp=$(echo "$current" | jq -r '.main.temp')
    local current_formatted=$(get_formatted_temp "$current_temp")

    # Process forecast (next 6 hours)
    local tooltip="<b>Hourly Forecast:</b>\n"
    local count=0

    while IFS= read -r hour; do
        local dt=$(echo "$hour" | jq -r '.dt' | xargs -I{} date -d @{} +"%H:%M")
        local temp=$(echo "$hour" | jq -r '.main.temp')
        local desc=$(echo "$hour" | jq -r '.weather[0].description')

        tooltip+="\n$dt: $(get_formatted_temp "$temp"), ${desc^}"

        count=$((count+1))
        if (( count >= 6 )); then
            break
        fi
    done < <(echo "$forecast" | jq -c '.list[]')

    # Output JSON for Waybar
    echo "{\"text\":\"$current_formatted\",\"tooltip\":\"$tooltip\"}"
}

monitor_weather
