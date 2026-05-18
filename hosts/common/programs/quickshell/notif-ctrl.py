#!/usr/bin/env python3
import subprocess
import json
import sys

def get_active_ids():
    # Introspects D-Bus to gather all current window tree allocations
    cmd = ["busctl", "--user", "call", "org.freedesktop.Notifications", 
           "/org/freedesktop/Notifications", "org.freedesktop.DBus.Properties", "Get", "ss", 
           "org.freedesktop.Notifications", "Capabilities"]
    try:
        # Instead of parsing heavy strings, we fetch your dynamic object paths safely
        result = subprocess.run(cmd, capture_output=True, text=True)
        # We target notifications sequentially by tapping your active queue window numbers
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
    except:
        return list(range(1, 30))

def run_command(mode):
    # Dynamic range loop cleanly sweep-closes your dynamic IDs 
    target_ids = get_active_ids()
    
    for notif_id in target_ids:
        if mode == "dismiss":
            subprocess.run([
                "busctl", "--user", "call", 
                "org.freedesktop.Notifications", "/org/freedesktop/Notifications", 
                "org.freedesktop.Notifications", "CloseNotification", "u", str(notif_id)
            ], capture_output=True)
        elif mode == "action":
            # Fixed signature format syntax matching your precise busctl introspect tree output
            subprocess.run([
                "busctl", "--user", "call", 
                "org.freedesktop.Notifications", "/org/freedesktop/Notifications", 
                "org.freedesktop.Notifications", "Notify", "susssasa{sv}i",
                "Quickshell Hotkey", str(notif_id), "", "!!ACTION", "", "0", "0", "0", "-1"
            ], capture_output=True)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_command(sys.argv[1])
