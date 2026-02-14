#!/usr/bin/env bash

if [ -z "$SWAYSOCK" ]; then
    RUNTIME_DIR="/run/user/$(id -u)" 
    if [ -d "$RUNTIME_DIR" ]; then
        SWAYSOCK=$(find "$RUNTIME_DIR" -maxdepth 1 -type s -name "sway-ipc.*.sock" -printf "%T@ %p\n" | sort -n | tail -1 | awk '{print $2}')
        export SWAYSOCK 
    fi
fi
if [ -z "$SWAYSOCK" ]; then
    echo "Error: SWAYSOCK environment variable not set and could not be found. Cannot connect to Sway." >&2
    exit 1 
fi

# Define your outputs exactly as they appear in 'swaymsg -t get_outputs'
# IMPORTANT: The order here matters for which output gets which image.
OUTPUTS=("DP-1" "DP-2" "HDMI-A-1" "HDMI-A-2")
WALLPAPER_DIR="/home/moonburst/Pictures/wallpapers"

# 1. Get a list of all suitable image files and shuffle them.
SHUFFLED_WALLPAPERS=()
while IFS= read -r -d $'\0' file; do
    SHUFFLED_WALLPAPERS+=("$file")
done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -z)

# Check if we have enough wallpapers for all outputs
NUM_OUTPUTS=${#OUTPUTS[@]}
NUM_WALLPAPERS=${#SHUFFLED_WALLPAPERS[@]}
if (( NUM_WALLPAPERS == 0 )); then
    echo "Error: No wallpapers found in $WALLPAPER_DIR. Cannot set backgrounds." >&2
    exit 1
fi

if (( NUM_WALLPAPERS < NUM_OUTPUTS )); then
    echo "Warning: Not enough unique wallpapers ($NUM_WALLPAPERS) for all outputs ($NUM_OUTPUTS). Some wallpapers might be repeated." >&2
fi

# 2. Assign unique wallpapers to each output
for i in "${!OUTPUTS[@]}"; do
    output="${OUTPUTS[$i]}"
    wallpaper_index=$(( i % NUM_WALLPAPERS ))
    RANDOM_WALLPAPER="${SHUFFLED_WALLPAPERS[$wallpaper_index]}"
    swaymsg "output \"$output\" bg \"$RANDOM_WALLPAPER\" fit"
done
