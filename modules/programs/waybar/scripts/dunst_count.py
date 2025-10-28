#!/usr/bin/env python3

import subprocess
import json
import time

# --- Configuration ---
# Set the update interval in seconds
INTERVAL = 1
# ---------------------

def get_dunst_status():
    """
    Executes dunstctl commands to get notification count and status.
    Returns the count and status strings, or None/default on failure.
    """
    count = "N/A"
    status = "false"
    
    # --- 1. Get Waiting Count ---
    try:
        # Executes: dunstctl count waiting
        count_process = subprocess.run(
            ['dunstctl', 'count', 'waiting'],
            capture_output=True,
            text=True,
            check=True
        )
        count = count_process.stdout.strip()
    except Exception:
        # If count fails, keep it as "N/A"
        pass
    
    # --- 2. Get Pause Status ---
    try:
        # Executes: dunstctl is-paused
        status_process = subprocess.run(
            ['dunstctl', 'is-paused'],
            capture_output=True,
            text=True,
            check=True
        )
        # The output is "true" or "false"
        status = status_process.stdout.strip()
    except Exception:
        # If status check fails, default to "false" (unpaused)
        status = "false"
        
    return count, status

if __name__ == "__main__":
    while True:
        try:
            # 1. Fetch data
            count, status = get_dunst_status()
            
            # 2. Determine final text based on status
            if status == "true":
                # Notifications are paused
                display_text = f"🔕 {count}"
                display_class = "paused"
            else:
                # Notifications are active/unpaused
                display_text = f"🔔 {count}"
                display_class = "active"

            # 3. Create Waybar JSON output
            waybar_output = {
                "text": display_text,
                "tooltip": f"Waiting: {count} notifications\nStatus: {'Paused' if status == 'true' else 'Active'}",
                "class": display_class
            }
            
            # 4. Print and Flush
            # Crucial for persistent mode: sends the update immediately to Waybar
            print(json.dumps(waybar_output), flush=True)
            
        except Exception as e:
            # Handle unhandled script errors
            error_output = {
                "text": "🗱 Error",
                "tooltip": f"Dunst Script Error: {e}",
                "class": "error"
            }
            print(json.dumps(error_output), flush=True)
            
        # 5. Wait for the next cycle
        time.sleep(INTERVAL)
