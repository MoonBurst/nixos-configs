#!/usr/bin/env bash

CPU_TEMP=$(sensors | awk '
    /^Tctl/ {
        gsub(/[+°C]/, "");
        for (i=1; i<=NF; i++) {
            if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
        gsub(/\..*/, "", $i);
                print $i;
                exit;
            }
        }
    }')

GPU_TEMP=$(sensors | awk '/^edge/ {gsub(/\+/,""); gsub(/\..*/,"",$2); print $2}' | head -n1)

case $CPU_TEMP in
    "N/A") COLOR="#d8dee9" && CPU_ICON="󰍛 ?" ;;
    [7-9][6-9]|[8-9][0-9]|100) COLOR="#bf616a" && CPU_ICON="" ;;  # Greater than 75
    [6][6-9]|7[0-5]) COLOR="#ebcb8b" && CPU_ICON="󰍛" ;;            # Between 66 and 75
    *) COLOR="#a3be8c" && CPU_ICON="󰍛" ;;                          # 65 or below
esac

case $GPU_TEMP in
    "N/A") GPU_ICON="󰢮 ?" ;;
    [7-9][1-9]|[8-9][0-9]|100) GPU_ICON="" ;;  # Greater than 71
    [5][1-9]|70) GPU_ICON="󰢮" ;;                # Between 51 and 70
    *) GPU_ICON="󰢮" ;;                          # 50 or below
esac

echo "$GPU_ICON $GPU_TEMP°C $CPU_ICON $CPU_TEMP°C"
