#!/usr/bin/env python3

import subprocess
import json
import re
import sys
from typing import List

# Regex to strip ALL ANSI escape codes. This is primarily a fallback, 
# as the shell command handles the bulk of the cleaning now.
ANSI_STRIP_REGEX = re.compile(r'\x1b\[[0-9;]*m')

# Define full paths for commands to ensure they run correctly outside of a full shell environment
PACMAN_CMD = "/usr/sbin/checkupdates"
AUR_CMD = "paru -Qua" # We pass the whole command string now

# Regex to strictly validate package names (alphanumeric, dash, underscore, dot)
PACKAGE_NAME_REGEX = re.compile(r'^[a-zA-Z0-9._-]+')


def get_updates_optimized(command: str) -> List[str]:
    """
    Runs an optimized shell command using a single pipeline (sed | awk) 
    to fetch updates, clean, and extract package names efficiently.
    """
    
    # 1. Define the complete shell pipeline command:
    # command: The update checker command (e.g., /usr/sbin/checkupdates)
    # sed -E 's/\x1b\[[0-9;]*m//g': Strips ANSI escape codes
    # awk '{print $1}': Prints only the first field (the package name) and adds a clean newline
    # This pipeline is the part that makes the Bash script so fast/robust.
    full_command = f"{command} 2>/dev/null | sed -E 's/\\x1b\\[[0-9;]*m//g' | awk '{{print $1}}'"
    
    try:
        # NOTE: We must use shell=True here to execute the pipeline string.
        # We also suppress check=True to allow non-zero exit codes (which means updates exist).
        result = subprocess.run(
            full_command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            encoding='utf-8', 
            check=False,
            timeout=15 
        )
        
        output = result.stdout.strip()
        
        if not output:
            return []

        # The output from AWK is already clean (one package per line, no extra fields).
        # We process it one line at a time to strictly validate and clean.
        packages = []
        for line in output.splitlines():
            package_name = line.strip()
            
            # --- Strict Filtering & Validation ---
            match = PACKAGE_NAME_REGEX.match(package_name)
            if match:
                packages.append(match.group(0))
            # --- END Strict Filtering ---

        return packages
        
    except subprocess.TimeoutExpired:
        # Extract command name for reporting
        cmd_name = command.split()[0].split('/')[-1]
        return [f"Timeout: {cmd_name}"]
    except Exception as e:
        cmd_name = command.split()[0].split('/')[-1]
        # In case the command itself isn't found, or another shell error occurs
        if "No such file or directory" in str(e):
             return [f"Tool missing: {cmd_name}"]
        return [f"Error running {cmd_name}: {str(e)}"]

def main():
    """Main function to fetch updates, format the output, and print JSON for Waybar."""
    
    # --- 1. Fetch updates using the optimized function ---
    # Pass the command string for the shell pipeline
    pacman_list = get_updates_optimized(PACMAN_CMD)
    aur_list = get_updates_optimized(AUR_CMD) 

    # Handle critical failures (missing tools) by reporting immediately
    error_list = [p for p in pacman_list if p.startswith("Tool missing:")] + \
                 [a for a in aur_list if a.startswith("Tool missing:")]
    
    if error_list:
        print(json.dumps({
            "text": "UPD ERR",
            "tooltip": f"Critical Error:\n{PACMAN_CMD} or {AUR_CMD.split()[0]} missing.",
            "class": "error"
        }), flush=True)
        sys.exit(0)


    # Filter out potential runtime errors/timeouts
    pacman_updates = [p for p in pacman_list if not p.startswith("Error running") and not p.startswith("Timeout:")]
    aur_updates = [a for a in aur_list if not a.startswith("Error running") and not a.startswith("Timeout:")]
    
    pacman_count = len(pacman_updates)
    aur_count = len(aur_updates)
    total_count = pacman_count + aur_count

    # --- 2. Tooltip Formatting ---
    tooltip_lines = []
    
    # CRITICAL CHANGE: Use the raw newline character (\n) and let json.dumps() escape it to \\n
    LINE_BREAK = "\n"

    if pacman_count > 0:
        tooltip_lines.append(f"Repo Updates ({pacman_count}):")
        # Packages are already clean, just join them
        tooltip_lines.append(LINE_BREAK.join(pacman_updates))

    if aur_count > 0:
        if pacman_count > 0:
            tooltip_lines.append("") # Add a blank line between repo and AUR sections
        
        tooltip_lines.append(f"AUR Updates ({aur_count}):")
        # Packages are already clean, just join them
        tooltip_lines.append(LINE_BREAK.join(aur_updates))
    
    # If there were partial errors, append them to the tooltip
    runtime_error_lines = [p for p in pacman_list if p.startswith("Error running") or p.startswith("Timeout:")] + \
                          [a for a in aur_list if a.startswith("Error running") or a.startswith("Timeout:")]
    if runtime_error_lines:
        if tooltip_lines:
             tooltip_lines.append("") 
        tooltip_lines.append("Script Errors:")
        tooltip_lines.append(LINE_BREAK.join(runtime_error_lines))

    # Join the main sections of the tooltip
    clean_tooltip = LINE_BREAK.join(tooltip_lines)


    # --- 3. JSON Output ---
    if total_count > 0:
        final_json = {
            "text": str(total_count),
            "tooltip": clean_tooltip,
            "class": "has-updates"
        }
    else:
        # If no updates and no runtime errors, output success
        if not runtime_error_lines:
            final_json = {
                "text": "0",
                "tooltip": "System is up to date.",
                "class": "updated"
            }
        else:
            # If 0 updates but one checker failed, report error/warning
            final_json = {
                "text": "0 (ERR)",
                "tooltip": clean_tooltip,
                "class": "warning"
            }


    print(json.dumps(final_json), flush=True)

if __name__ == "__main__":
    main()
