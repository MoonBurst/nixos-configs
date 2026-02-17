#!/usr/bin/env bash

# Paths and Environment
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="wayland-0"
export DISPLAY=":0"

case "$1" in
    "ui")
        # If not running, start it
        if ! audtool current-song >/dev/null 2>&1; then
            audacious &
            sleep 1
        fi
        # Bring the window to the front
        audtool mainwin-show
        ;;
    "add")
        files=$(yad --file --multiple --separator="\n" --title="Add to Audacious" --width=800 --height=600)
        [ -n "$files" ] && echo -e "$files" | while read -r line; do audtool playlist-addurl "$line"; done
        ;;
    *)
        # F11 / Default Logic
        if audtool current-song >/dev/null 2>&1; then
            # If running, toggle play/pause
            STATUS=$(audtool playback-status)
            if [ "$STATUS" = "playing" ]; then
                audtool playback-pause
            else
                audtool playback-play
            fi
        else
            # STARTUP FIX:
            # We start Audacious normally (so the UI is available),
            # but we immediately tell it to hide its window.
            audacious &

            # Wait for it to wake up
            MAX_RETRIES=10
            while ! audtool current-song >/dev/null 2>&1 && [ $MAX_RETRIES -gt 0 ]; do
                sleep 0.5
                ((MAX_RETRIES--))
            done

            # Hide it immediately so it 'feels' like it started minimized
            audtool mainwin-show off
            audtool playback-play
        fi
        ;;
esac
