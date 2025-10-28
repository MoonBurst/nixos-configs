#!/usr/bin/env python3

import subprocess
import json
import time
import sys

# --- Configuration ---
# Thresholds in GiB (as integers)
RED_THRESHOLD = 8
WARN_THRESHOLD = 16

# Colors for Pango markup
LOW = "#FF0000"       # Red for < 8 GiB
WARN = "#FFA500"      # Orange for >= 8 GiB and < 16 GiB
SUFFICIENT = "#00FF00" # Green for >= 16 GiB

# The update interval in seconds for the continuous loop
INTERVAL = 1
# ---------------------

def get_available_memory():
    """
    Reads MemAvailable from /proc/meminfo and converts it to GiB (integer).
    This method is often faster and more reliable than running 'free'.
    """
    
    available_memory_gib = None
    try:
        # Read /proc/meminfo content
        with open('/proc/meminfo', 'r') as f:
            content = f.read()

        # Find MemAvailable line and extract value in KiB
        for line in content.splitlines():
            if line.startswith('MemAvailable:'):
                # Format: MemAvailable:         1234567 KiB
                # Split by whitespace, get the second element (the number), strip ' KiB'
                mem_kib_str = line.split()[1]
                mem_kib = int(mem_kib_str)
                
                # Convert KiB to GiB (integer truncation)
                # 1 GiB = 1024 * 1024 KiB = 1048576 KiB
                available_memory_gib = mem_kib // 1048576 
                break
                
    except Exception as e:
        # Log error to stderr for debugging
        # print(f"Error fetching memory from /proc/meminfo: {e}", file=sys.stderr)
        available_memory_gib = None
        
    return available_memory_gib

def format_output(available_memory):
    """Applies color logic and formats the final output string."""
    
    if available_memory is None:
        color = WARN
        display_text = "RAM: N/A GiB"
        display_class = "error"
    else:
        # Apply the color logic based on the Bash script's rules
        if available_memory < RED_THRESHOLD:
            color = LOW
            display_class = "critical"
        elif available_memory < WARN_THRESHOLD:
            color = WARN
            display_class = "warning"
        else:
            color = SUFFICIENT
            display_class = "normal"
            
        # Pango markup output
        display_text = f"<span foreground='{color}'>RAM: {available_memory} GiB</span>"

    # Create Waybar JSON output
    waybar_output = {
        "text": display_text,
        "tooltip": f"Available Memory: {available_memory} GiB",
        "class": display_class
    }
    
    return waybar_output

# ----------------------------------------------------------------------
# CONTINUOUS EXECUTION BLOCK FOR WAYBAR
# ----------------------------------------------------------------------
if __name__ == "__main__":
    # Check if we are running in a short-lived execution (e.g., performance test)
    # If the script receives arguments, assume it's a single test run and should exit after one cycle.
    is_test_run = len(sys.argv) > 1

    while True:
        try:
            # 1. Fetch data
            available_memory = get_available_memory()
            
            # 2. Format and generate JSON
            output_json = format_output(available_memory)
            
            # 3. Print and Flush
            # Printing a JSON string and flushing ensures Waybar receives the update immediately.
            print(json.dumps(output_json), flush=True)
            
            # If it's a test run, exit immediately after the first successful output.
            if is_test_run:
                sys.exit(0)
            
        except Exception as e:
            # Handle unhandled script errors
            error_output = {
                "text": "🗱 RAM Error",
                "tooltip": f"RAM Script Crash: {e}",
                "class": "error"
            }
            print(json.dumps(error_output), flush=True)
            
            # If it's a test run, exit immediately after the error.
            if is_test_run:
                sys.exit(1)
            
        # 4. Wait for the next cycle (only runs if not a test run)
        time.sleep(INTERVAL)
