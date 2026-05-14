#!/usr/bin/env bash

# Paths and Environment
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="wayland-0"
export DISPLAY=":0"

# --- Anti-Burn-In Color Engine ---
# Gently shifts a default muted teal/slate tone (#81a1c1) by a tiny fraction
# depending on the current minute to prevent fixed panel polarization.
shift_color() {
    local target_color="#81a1c1" # Clean, low-stress pastel blue-gray
    local current_min=$(date +%M)
    local offset_dec=$(( 10#$current_min / 4 )) # Restricts variance from 0 to 15

    local hex_clean="${target_color#\#}"
    local r_hex="${hex_clean:0:2}"
    local g_hex="${hex_clean:2:2}"
    local b_hex="${hex_clean:4:2}"

    local r_dec=$((16#$r_hex))
    local g_dec=$((16#$g_hex))
    local b_dec=$((16#$b_hex))

    local r_mutated g_mutated b_mutated
    if [ $((10#$current_min % 2)) -eq 0 ]; then
        r_mutated=$(( r_dec + offset_dec ))
        g_mutated=$(( g_dec - offset_dec ))
        b_mutated=$(( b_dec + offset_dec ))
    else
        r_mutated=$(( r_dec - offset_dec ))
        g_mutated=$(( g_dec + offset_dec ))
        b_mutated=$(( b_dec - offset_dec ))
    fi

    # Hardware clip constraints
    [ $r_mutated -gt 255 ] && r_mutated=255; [ $r_mutated -lt 0 ] && r_mutated=0
    [ $g_mutated -gt 255 ] && g_mutated=255; [ $g_mutated -lt 0 ] && g_mutated=0
    [ $b_mutated -gt 255 ] && b_mutated=255; [ $b_mutated -lt 0 ] && b_mutated=0

    printf "#%02x%02x%02x" $r_mutated $g_mutated $b_mutated
}

case "${1:-default}" in
    "ui")
        if ! audtool current-song >/dev/null 2>&1; then
            audacious &
            sleep 1
        fi
        audtool mainwin-show
        ;;
    "add")
        files=$(yad --file --multiple --separator="\n" --title="Add to Audacious" --width=800 --height=600)
        [ -n "$files" ] && echo -e "$files" | while read -r line; do audtool playlist-addurl "$line"; done
        ;;
    "toggle")
        # Explicit toggle hook for keybindings or mouse-clicks
        if audtool current-song >/dev/null 2>&1; then
            STATUS=$(audtool playback-status)
            if [ "$STATUS" = "playing" ]; then
                audtool playback-pause
            else
                audtool playback-play
            fi
        fi
        ;;
    *)
        # Default Logic: Formats a micro-shifting status output string for Waybar
        if audtool current-song >/dev/null 2>&1; then
            STATUS=$(audtool playback-status)
            SONG_TITLE=$(audtool current-song)

            # Choose an icon based on core music status
            if [ "$STATUS" = "playing" ]; then
                ICON="  "
            else
                ICON="  "
            fi

            # Truncate song title safely if it is too long to prevent breaking bar geometry
            if [ "${#SONG_TITLE}" -gt 35 ]; then
                SONG_TITLE="${SONG_TITLE:0:32}..."
            fi

            MUT_COLOR=$(shift_color)
            echo "<span foreground=\"$MUT_COLOR\">$ICON $SONG_TITLE</span>"
        else
            # If completely stopped/closed, return a completely empty string
            # to let Waybar hide the module space dynamically, preventing static text burn.
            echo ""
        fi
        ;;
esac
