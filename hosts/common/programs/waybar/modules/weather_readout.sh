#!/usr/bin/env bash

# Enable strict mode
set -euo pipefail

# This script fetches current weather and forecast data from OpenWeatherMap,
# applies temperature-based color thresholds, and outputs JSON for Waybar
# with current temp as primary text and 6-hour forecast as tooltip.

# ==========================================================
#                CONFIGURATION
# ==========================================================

CITY=$(cat /run/secrets/weather_city | xargs)
API_KEY=$(cat /run/secrets/weather_api_key | xargs)

# Color tags (Pango Markup)
GREEN_TAG="<span foreground='#33FF33'>%s</span>"
YELLOW_TAG="<span foreground='yellow'>%s</span>"
RED_TAG="<span foreground='#FF0000'>%s</span>"

# ==========================================================

get_formatted_temp() {
    local temp_k=$1
    local temp_f=$(awk -v temp=$temp_k 'BEGIN{ printf("%.0f", ((temp - 273.15) * 9/5) + 32) }')

    if (( temp_f >= 86 )); then
        printf "$RED_TAG" "${temp_f}°F"
    elif (( temp_f >= 77 )); then
        printf "$YELLOW_TAG" "${temp_f}°F"
    else
        printf "$GREEN_TAG" "${temp_f}°F"
    fi
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
