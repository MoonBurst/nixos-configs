#!/usr/bin/env python3

import subprocess
import json
import time
import sys
from typing import Optional, Dict, Any, Tuple

# --- Configuration ---
# Thresholds defined as (WARN, CRIT) pairs
TEMP_WARNING = (76, 90)     # Temperature in Celsius
UTIL_WARNING = (50, 80)     # GPU Utilization in percent
POWER_WARNING = (150, 300)  # Power in Watts
VRAM_USED_PCT_WARNING = (50, 75) # VRAM Used in percent

# Colors for Pango markup
COLOR_CRITICAL = "#ff0000"
COLOR_WARNING = "#ffa500"
COLOR_DEFAULT = "#00FF00"
COLOR_PADDING = "#262626"

# The update interval in seconds for the continuous loop
INTERVAL = 1

# Constant for byte conversion
BYTES_PER_GIB = 1073741824
# ---------------------

def determine_color(value: float, warn: float, crit: float) -> str:
    """Determines the color code based on the value and thresholds."""
    if value > crit:
        return COLOR_CRITICAL
    elif value > warn:
        return COLOR_WARNING
    return COLOR_DEFAULT

def get_gpu_data(device_id: int) -> Optional[Dict[str, Any]]:
    """
    Fetches and parses GPU metrics from rocm-smi for a given device ID.
    
    NOTE: Explicitly redirects stderr to DEVNULL to prevent rocm-smi 
    error messages/warnings from polluting stdout (which causes Waybar's JSON error).
    """
    metrics = {
        'temp': 0.0, 'power': 0.0, 'util': 0.0,
        'vram_total_b': 0, 'vram_used_b': 0
    }
    
    # --- 1. Primary ROCM-SMI Call & Extraction ---
    try:
        # Removed check=True to prevent script crash on non-zero exit codes (common with rocm-smi errors)
        result = subprocess.run(
            ['rocm-smi', '-d', str(device_id), '-a', '--showmeminfo', 'VRAM'],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, # Discard stderr output to prevent JSON parsing error
            text=True, 
            # check=True removed for robustness
            timeout=5
        )
        rocm_output = result.stdout
        
        # If the command failed to execute or returned an empty output, treat as failure
        if not rocm_output and result.returncode != 0:
            return None
            
    except Exception:
        # Catches FileNotFoundError or TimeoutExpired
        return None

    # Parsing the output line by line is safer than complex shell pipelines in Python subprocesses
    lines = rocm_output.splitlines()

    for line in lines:
        if "Temperature (Sensor junction)" in line:
            try:
                metrics['temp'] = float(line.split()[-1].replace('C', '').replace('°', ''))
            except ValueError: pass
        elif "Average Graphics Package Power" in line:
            try:
                metrics['power'] = float(line.split()[-1].replace('W', ''))
            except ValueError: pass
        elif "GPU use (%)" in line:
            try:
                metrics['util'] = float(line.split()[-1].replace('%', ''))
            except ValueError: pass
        elif "VRAM Total Memory (B)" in line:
            try:
                # Get the last element and remove non-digit characters
                metrics['vram_total_b'] = int("".join(filter(str.isdigit, line.split()[-1])))
            except ValueError: pass
        elif "VRAM Total Used Memory (B)" in line:
            try:
                # Get the last element and remove non-digit characters
                metrics['vram_used_b'] = int("".join(filter(str.isdigit, line.split()[-1])))
            except ValueError: pass

    # --- 2. VRAM CSV Fallback Logic (Handles cases where bytes aren't reported directly) ---
    if metrics['vram_total_b'] == 0 or metrics['vram_used_b'] == 0:
        try:
            # Removed check=True here as well for robustness
            csv_result = subprocess.run(
                ['rocm-smi', '--showmeminfo', 'VRAM', '--csv'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL, # Discard stderr output
                text=True, 
                # check=True removed for robustness
                timeout=5
            )
            csv_output = csv_result.stdout
            
            # Find the line for the specific device, usually starting with "cardX,"
            target_line = next((line for line in csv_output.splitlines() if line.startswith(f"card{device_id},")), None)
            
            if target_line:
                # CSV format is generally: cardX,Total Memory (B),Used Memory (B),...
                parts = target_line.split(',')
                if len(parts) >= 3:
                    total_csv = int("".join(filter(str.isdigit, parts[1])))
                    used_csv = int("".join(filter(str.isdigit, parts[2])))

                    if metrics['vram_total_b'] == 0 and total_csv != 0:
                        metrics['vram_total_b'] = total_csv
                    if metrics['vram_used_b'] == 0 and used_csv != 0:
                        metrics['vram_used_b'] = used_csv
        except Exception:
            pass # Silently fail on CSV extraction errors
            
    # --- 3. Final Check (Matching Bash Script's Core Metric Validation) ---
    # If all core metrics (Temp, Util, Power) are still zero, the parsing failed completely.
    if metrics['temp'] == 0.0 and metrics['util'] == 0.0 and metrics['power'] == 0.0:
         return None

    return metrics

def format_metrics(metrics: Dict[str, Any], device_id: int) -> Tuple[str, str, str]:
    """Applies color logic and formats the final output string and tooltip."""
    
    # --- VRAM Calculation ---
    vram_color = COLOR_DEFAULT
    vram_display_value = "N/A"
    
    vram_total_b = metrics['vram_total_b']
    vram_used_b = metrics['vram_used_b']
    
    if vram_total_b > 0 and vram_used_b >= 0:
        # Calculate remaining GiB
        vram_remaining_b = max(0, vram_total_b - vram_used_b)
        vram_display_value = f"{vram_remaining_b / BYTES_PER_GIB:.1f}"
        
        # Calculate used percentage for coloring
        vram_used_pct = (vram_used_b / vram_total_b) * 100
        vram_color = determine_color(
            vram_used_pct, 
            VRAM_USED_PCT_WARNING[0], 
            VRAM_USED_PCT_WARNING[1]
        )
    elif vram_used_b > 0:
        # Fallback: display used memory if total is unavailable
        vram_display_value = f"{vram_used_b / BYTES_PER_GIB:.1f} used"
        vram_color = COLOR_DEFAULT

    # --- Determine Colors ---
    temp_color = determine_color(metrics['temp'], TEMP_WARNING[0], TEMP_WARNING[1])
    power_color = determine_color(metrics['power'], POWER_WARNING[0], POWER_WARNING[1])
    util_color = determine_color(metrics['util'], UTIL_WARNING[0], UTIL_WARNING[1])

    # --- Determine Overall Status Color (Highest Severity) ---
    severity_map = {COLOR_CRITICAL: 3, COLOR_WARNING: 2, COLOR_DEFAULT: 1}
    max_severity = max(
        severity_map[temp_color],
        severity_map[power_color],
        severity_map[util_color],
        severity_map[vram_color]
    )
    overall_color = next(k for k, v in severity_map.items() if v == max_severity)

    # --- Formatting Helpers ---
    def get_padded_span(value, target_len, color, unit):
        val_str = f"{int(value):.0f}"
        padding = ""
        # Calculate how many leading spaces (represented by padded zeros) are needed
        if len(val_str) < target_len:
            padding_len = target_len - len(val_str)
            padding = f'<span foreground="{COLOR_PADDING}">' + '0' * padding_len + '</span>'
        # Include the unit inside the colored span
        return f'<span foreground="{color}">{padding}{val_str}{unit}</span>'

    # --- Final Text Output (Pango) ---
    final_text = (
        # CHANGED: Removed device_id from the GPU label
        f'<span foreground="{overall_color}">GPU:</span> '
        f'{get_padded_span(metrics["temp"], 3, temp_color, "°C")} '
        f'{get_padded_span(metrics["util"], 3, util_color, "%")} '
        f'{get_padded_span(metrics["power"], 3, power_color, "W")} '
        f'<span foreground="{vram_color}">VRAM: {vram_display_value} GiB</span>'
    )

    # --- Tooltip Output ---
    tooltip_text = (
        f"Device ID: {device_id}\n"
        f"Junction Temp: {metrics['temp']:.1f}°C\n"
        f"Utilization: {metrics['util']:.1f}%\n"
        f"Power: {metrics['power']:.1f}W\n"
        f"VRAM Used: {vram_used_b / BYTES_PER_GIB:.1f} GiB / {vram_total_b / BYTES_PER_GIB:.1f} GiB"
    )

    return final_text, tooltip_text, "gpu-active" if max_severity > 1 else "gpu-normal"


# ----------------------------------------------------------------------
# CONTINUOUS EXECUTION BLOCK FOR WAYBAR
# ----------------------------------------------------------------------
if __name__ == "__main__":
    # The script expects the device ID (0 or 1) as the first command-line argument.
    if len(sys.argv) < 2 or sys.argv[1] not in ('0', '1'):
        # Output error message in JSON format for Waybar
        error_output = {
            "text": "GPU ERR",
            "tooltip": "Invalid or missing Device ID argument. Use 0 or 1.",
            "class": "error"
        }
        print(json.dumps(error_output), flush=True)
        # Exit immediately, not in a loop
        sys.exit(1)
        
    DEVICE_ID = int(sys.argv[1])
    
    while True:
        try:
            # 1. Fetch data
            metrics = get_gpu_data(DEVICE_ID)
            
            if metrics is None:
                # If fetching failed, raise an exception to print the fallback JSON error
                raise Exception("ROCm-SMI failed or returned empty data.")
            
            # 2. Format and generate JSON
            final_text, tooltip_text, display_class = format_metrics(metrics, DEVICE_ID)

            output_json = {
                "text": final_text,
                "tooltip": tooltip_text,
                "class": display_class
            }
            
            # 3. Print and Flush
            print(json.dumps(output_json), flush=True)
            
        except Exception as e:
            # This block prints valid JSON containing the error message
            error_output = {
                "text": f"GPU{DEVICE_ID} FAIL",
                "tooltip": f"GPU Script Crash: {e}",
                "class": "error"
            }
            print(json.dumps(error_output), flush=True)
            
        # 4. Wait for the next cycle
        time.sleep(INTERVAL)
