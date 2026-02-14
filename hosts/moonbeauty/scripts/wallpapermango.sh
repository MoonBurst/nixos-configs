#!/usr/bin/env bash
# Wait a moment for outputs to settle, especially during startup
sleep 1

# Kill any existing background processes
pkill swaybg
pkill wbg

# --- Configuration ---
OUTPUTS=("DP-1" "DP-2" "HDMI-A-1")
WALLPAPER_DIR="/home/moonburst/Pictures/wallpapers"
BLACK_COLOR="#000000"
# --- End Configuration ---

# Set ALL monitors to solid BLACK.
for output in "${OUTPUTS[@]}"; do
    swaybg -o "$output" -c "$BLACK_COLOR" &
done
sleep 0.5 # Give it time to draw the black.

# --- Image Logic (Same as before) ---
SHUFFLED_WALLPAPERS=()
while IFS= read -r -d $'\0' file; do
    SHUFFLED_WALLPAPERS+=("$file")
done < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -z)

NUM_WALLPAPERS=${#SHUFFLED_WALLPAPERS[@]}

if (( NUM_WALLPAPERS == 0 )); then
    echo "Error: No wallpapers found in $WALLPAPER_DIR. Cannot set backgrounds." >&2
    exit 1
fi

# Layer the images using 'swaybg -m fit'.
for i in "${!OUTPUTS[@]}"; do
    output="${OUTPUTS[$i]}"
    wallpaper_index=$(( i % NUM_WALLPAPERS ))
    RANDOM_WALLPAPER="${SHUFFLED_WALLPAPERS[$wallpaper_index]}"
    
    # Layer the image using 'fit' mode.
    swaybg -o "$output" -i "$RANDOM_WALLPAPER" -m fit &
done
