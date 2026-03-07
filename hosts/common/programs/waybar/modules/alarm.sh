#!/usr/bin/env bash

# Path to the state file
STATE_FILE="/tmp/waybar_alarm_state"

# Mode: Cancel
if [[ "$1" == "cancel" ]]; then
    rm -f "$STATE_FILE"
    pkill -RTMIN+8 waybar # Trigger Waybar refresh
    exit 0
fi

# Mode: Set
if [[ "$1" == "set" ]]; then
    # --fixed: Prevents the window from expanding to fill the screen
    # --center: Places the dialog in the middle of the monitor
    # --width/--height: Sets specific small dimensions
    # --on-top: Keeps the dialog above other windows

    timer=$(yad --entry \
        --title="Set Alarm" \
        --text="Enter time (e.g. 5m, 1h30m, 10s):" \
        --width=350 --height=100 \
        --fixed --center --on-top \
        --button="OK:0" --button="Cancel:1")

    # Exit if user cancels or enters nothing
    [[ $? -ne 0 || -z "$timer" ]] && exit 0

    message=$(yad --entry \
        --title="Set Message" \
        --text="Enter message:" \
        --entry-text="Alarm Finished!" \
        --width=350 --height=100 \
        --fixed --center --on-top \
        --button="OK:0" --button="Cancel:1")

    [[ $? -ne 0 || -z "$message" ]] && message="Alarm Finished!"

    # Parse time to total seconds
    total_seconds=0
    temp_timer="$timer"
    while [[ $temp_timer =~ ([0-9]+)([hms]) ]]; do
        num=${BASH_REMATCH[1]}; unit=${BASH_REMATCH[2]}
        case "$unit" in
            h) total_seconds=$((total_seconds + num * 3600)) ;;
            m) total_seconds=$((total_seconds + num * 60)) ;;
            s) total_seconds=$((total_seconds + num)) ;;
        esac
        temp_timer=${temp_timer/${BASH_REMATCH[0]}/}
    done

    # If parsing fails, default to minutes if it's just a number
    if [[ $total_seconds -eq 0 && $timer =~ ^[0-9]+$ ]]; then
        total_seconds=$((timer * 60))
    fi

    [[ $total_seconds -eq 0 ]] && exit 1

    # Store start time, total seconds, and message
    echo "$(date +%s) $total_seconds \"$message\"" > "$STATE_FILE"
    pkill -RTMIN+8 waybar
    exit 0
fi

# Mode: Display (Waybar Exec)
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"text": "   Off", "class": "none"}'
    exit 0
fi

read start_time total_seconds message < "$STATE_FILE"
# Strip quotes from message for display/notification
clean_msg=$(echo "$message" | sed 's/"//g')

current_time=$(date +%s)
elapsed=$((current_time - start_time))
remaining=$((total_seconds - elapsed))

if [ $remaining -le 0 ]; then
    # Finished state: Flashing class and notify
    notify-send "Alarm" "$clean_msg"
    play ~/Documents/communicator.mp3 &
    echo "{\"text\": \"   Done!\", \"class\": \"warning\", \"percentage\": 100}"

    rm -f "$STATE_FILE"
    # Keep "Done!" visible for 10 seconds, then clear
    (sleep 10 && pkill -RTMIN+8 waybar) &
else
    # Active state: Calculate percentage for bar and format time
    percent=$(( 100 * elapsed / total_seconds ))
    h=$((remaining / 3600)); m=$(( (remaining % 3600) / 60 )); s=$((remaining % 60))
    time_str=$(printf "%02dh %02dm %02ds" $h $m $s)

    echo "{\"text\": \"   $time_str\", \"percentage\": $percent, \"class\": \"active\"}"
fi
