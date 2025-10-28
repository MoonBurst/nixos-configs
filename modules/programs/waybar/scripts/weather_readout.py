#!/usr/bin/python3
# This script is designed to run in a continuous loop and handles its own timing (5 minutes).

import json
import sys
import time
from typing import Dict, Any

# ==============================================================================
#                 USER CONFIGURATION
# ==============================================================================

# 1. Weather Location and API
CITY = "Houston"
API_KEY = "340c6f5eecff61ffd342313e4f2a7547" 

# 2. Update Interval (in seconds)
# Set to 300 seconds for 5 minutes (OpenWeatherMap generally updates every 10 mins).
UPDATE_INTERVAL = 300 

# 3. Temperature Thresholds (in Fahrenheit)
TEMP_WARN = 77  # Temperature above or equal to this is YELLOW (Warning)
TEMP_CRIT = 86  # Temperature above or equal to this is RED (Critical)

# 4. Pango Markup Colors (Hex values)
GREEN_HEX = "#00FF00" 
YELLOW_HEX = "yellow"
RED_HEX = "#FF0000"

# ==============================================================================
#                 SCRIPT LOGIC
# ==============================================================================

def get_pango_tag(color_hex: str) -> str:
    """Returns the opening Pango markup tag for a given hex color."""
    return f"<span foreground='{color_hex}'>"

def format_output(temp_f: float, description: str, color_tag: str) -> str:
    """Formats the final output string in Pango markup."""
    # Round temperature to one decimal place for display
    display_temp = f"{temp_f:.1f}"
    
    # Construct the Waybar JSON output
    main_text = f"{color_tag}{display_temp}°F</span>"
    
    # Use raw newline \n; json.dumps() will escape it to \\n
    tooltip_content = f"Weather in {CITY}:\n{display_temp}°F\n{description.capitalize()}"

    return json.dumps({
        "text": main_text,
        "tooltip": tooltip_content,
        "class": "weather-display"
    })

def fetch_weather_data(requests_lib) -> Dict[str, Any]:
    """Fetches weather data from OpenWeatherMap."""
    # Use the globally determined API_KEY
    url = f"https://api.openweathermap.org/data/2.5/weather?q={CITY}&appid={API_KEY}"
    
    # Use try-except for robust error handling of the network request
    try:
        response = requests_lib.get(url, timeout=10)
        response.raise_for_status() # Raise an exception for bad status codes (4xx or 5xx)
        return response.json()
    except requests_lib.exceptions.Timeout:
        return {"error": "Request timed out."}
    except requests_lib.exceptions.RequestException as e:
        return {"error": f"Network Error: {e}"}
    except json.JSONDecodeError:
        return {"error": "Failed to decode JSON."}


def process_weather(weather_data: Dict[str, Any]):
    """Processes weather data, determines color, and prints the result."""
    
    # Handle API errors
    if "error" in weather_data or weather_data.get('cod') == '404':
        error_msg = weather_data.get("error", "City not found.")
        print(json.dumps({
            "text": "Weather N/A",
            "tooltip": f"Weather data unavailable: {error_msg}",
            "class": "error"
        }), file=sys.stdout, flush=True)
        return

    try:
        # Extract temperature in Kelvin
        temp_k = weather_data['main']['temp']
        description = weather_data['weather'][0]['description']

        # 1. Convert Kelvin to Fahrenheit
        temp_f = (temp_k - 273.15) * 9/5 + 32
        
        # 2. Round the temperature to the nearest whole number for threshold comparison
        rounded_temp = round(temp_f)

        # 3. Determine Color Tag based on thresholds
        color_tag = get_pango_tag(GREEN_HEX) # Default to Green

        if rounded_temp >= TEMP_CRIT:
            color_tag = get_pango_tag(RED_HEX)
        elif rounded_temp >= TEMP_WARN:
            color_tag = get_pango_tag(YELLOW_HEX)
        
        # 4. Print final JSON
        print(format_output(temp_f, description, color_tag), file=sys.stdout, flush=True)

    except KeyError:
        print(json.dumps({
            "text": "Weather N/A",
            "tooltip": "API response missing expected data fields.",
            "class": "error"
        }), file=sys.stdout, flush=True)

def main():
    """Main execution block: import requests, fetch data, process, and run in a continuous loop."""
    
    # CRITICAL CHECK: Ensure 'requests' is installed
    try:
        import requests
    except ModuleNotFoundError:
        # Output error JSON if the dependency is missing
        print(json.dumps({
            "text": "Weather ERR",
            "tooltip": "Python 'requests' library missing. Install with 'pip install requests'",
            "class": "error"
        }), file=sys.stdout, flush=True)
        sys.exit(1)
    
    # Check if a custom interval was passed via command line (overrides default)
    interval = UPDATE_INTERVAL
    if len(sys.argv) > 1 and sys.argv[1].isdigit():
        interval = int(sys.argv[1])
    
    while True:
        # Fetch and process the data
        weather_data = fetch_weather_data(requests) 
        process_weather(weather_data)
        
        # Wait for the specified interval before checking again
        time.sleep(interval)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Final, ultimate catch-all to prevent silent crashes
        print(json.dumps({
            "text": "Fatal ERR",
            "tooltip": f"A fatal script error occurred: {e}",
            "class": "fatal-error"
        }), file=sys.stdout, flush=True)
        sys.exit(1)
