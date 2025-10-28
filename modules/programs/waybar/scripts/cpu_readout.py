#!/usr/bin/env python3

import subprocess
import sys
import json
import time

# --- Configuration ---
CRIT = "#f53c3c"
WARN = "#ffa500"
NORM = "#00FF00"
PAD = "#262626"

T_WARN = 65
T_CRIT = 70
U_WARN = 50
U_CRIT = 80

# The update interval in seconds for the continuous loop
INTERVAL = 2
# ---------------------

def get_cpu_data():
    """Fetches CPU temperature and usage using system commands."""
    
    # --- 1. Get CPU Temperature (Tctl) ---
    try:
        # Run 'sensors' and pipe to 'awk' for robust text parsing
        command = "sensors | awk '/Tctl/{print $2; exit}'"
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            capture_output=True,
            text=True
        )
        temp_str = result.stdout.strip().replace('+', '').replace('°C', '')
        
        # Convert to integer, rounding to the nearest whole number
        temp_c = int(float(temp_str) + 0.5) if temp_str else None
    except Exception:
        temp_c = None 

    # --- 2. Get CPU Usage (%) ---
    try:
        # Run 'top -bn1' and pipe to 'awk' to get the CPU usage
        command = "top -bn1 | awk '/%Cpu/ {print 100 - $8; exit}'"
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            capture_output=True,
            text=True
        )
        # Convert to integer
        cpu_u = int(float(result.stdout.strip()))
    except Exception:
        cpu_u = None
        
    return temp_c, cpu_u

def format_output(temp_c, cpu_u):
    """Applies color logic and formats the final output string."""
    
    # --- 1. Determine Component Colors and Values ---
    
    # CPU Temperature Logic
    T_SEVERITY = 1 # Default to NORM
    if temp_c is None:
        T_COLOR = NORM
        T_VAL = "N/A"
    else:
        if temp_c >= T_CRIT:
            T_COLOR = CRIT
            T_SEVERITY = 3
        elif temp_c >= T_WARN:
            T_COLOR = WARN
            T_SEVERITY = 2
        else:
            T_COLOR = NORM
            T_SEVERITY = 1
        T_VAL = f"{temp_c}°C"


    # CPU Usage Logic
    U_SEVERITY = 1 # Default to NORM
    if cpu_u is None:
        U_COLOR = NORM
        U_VAL = "N/A"
    else:
        if cpu_u >= U_CRIT:
            U_COLOR = CRIT
            U_SEVERITY = 3
        elif cpu_u >= U_WARN:
            U_COLOR = WARN
            U_SEVERITY = 2
        else:
            U_COLOR = NORM
            U_SEVERITY = 1
            
        # Format: Pad with leading zeros (e.g., 007, 034, 100)
        u_val_formatted = f"{cpu_u:03d}"
        
        # Logic to "pad" the leading zeros with a dimmed color (`PAD`) using Pango markup
        if cpu_u < 10:
            # e.g., '007' -> <span color="#262626">00</span>7
            u_val_formatted = u_val_formatted.replace('00', f'<span color="{PAD}">00</span>', 1)
        elif cpu_u < 100:
            # e.g., '034' -> <span color="#262626">0</span>34
            u_val_formatted = u_val_formatted.replace('0', f'<span color="{PAD}">0</span>', 1)
            
        U_VAL = f"{u_val_formatted}%"
        
    # --- 2. Determine Overall (Label) Color ---
    # Get the highest severity level
    MAX_SEVERITY = max(T_SEVERITY, U_SEVERITY)
    
    # Convert highest severity back to hex color for the "CPU:" label
    if MAX_SEVERITY == 3:
        LABEL_COLOR = CRIT
    elif MAX_SEVERITY == 2:
        LABEL_COLOR = WARN
    else: # MAX_SEVERITY == 1
        LABEL_COLOR = NORM
        
    # --- 3. Print Final Output ---
    final_text = (
        f'<span color="{LABEL_COLOR}">CPU:</span>'
        f' <span color="{T_COLOR}">{T_VAL}</span>'
        f' <span color="{U_COLOR}">{U_VAL}</span>'
    )
    
    # Generate a detailed tooltip
    tooltip_text = f"CPU Temp: {T_VAL}\nCPU Usage: {U_VAL.replace(f'<span color=\"{PAD}\">', '').replace('</span>', '')}"

    return final_text, tooltip_text

# ----------------------------------------------------------------------
# CONTINUOUS EXECUTION BLOCK FOR WAYBAR
# ----------------------------------------------------------------------
if __name__ == "__main__":
    while True:
        try:
            # 1. Fetch data
            temp_c, cpu_u = get_cpu_data()
            
            # 2. Format output
            final_text, tooltip_text = format_output(temp_c, cpu_u)
            
            # 3. Create the Waybar JSON object
            waybar_output = {
                "text": final_text,
                "tooltip": tooltip_text,
                "class": "normal" # Optional class for CSS styling
            }
            
            # 4. Print and Flush
            # Printing a JSON string and flushing ensures Waybar receives the update immediately.
            print(json.dumps(waybar_output), flush=True)
            
        except Exception as e:
            # Handle script errors gracefully by printing an error message
            error_output = {
                "text": "<span color=\"#FF0000\">CPU ERR</span>",
                "tooltip": f"Script Error: {e}",
                "class": "error"
            }
            print(json.dumps(error_output), flush=True)
            
        # 5. Wait for the next cycle
        time.sleep(INTERVAL)
