#!/usr/bin/env bash

# File to track current timer state
STATE_FILE="/tmp/waybar_alarm_state"

#Cancel
if [[ "$1" == "cancel" ]]; then
    rm -f "$STATE_FILE"
    pkill -RTMIN+8 waybar # Force waybar to refresh immediately
    exit 0
fi

# Mode: Setting the timer via GUI prompt
if [[ "$1" == "set" ]]; then
    timer=$(zenity --entry --title="Set Alarm" --text="Enter time (e.g. 5m, 1h):")
    [[ -z "$timer" ]] && exit 0
    message=$(zenity --entry --title="Set Message" --text="Enter message:")
    [[ -z "$message" ]] && message="Alarm Finished!"
    
    # Store start time and duration
    echo "$(date +%s) $timer $message" > "$STATE_FILE"
    pkill -RTMIN+8 waybar # Signal Waybar to refresh immediately
    exit 0
fi

# Mode: Displaying the countdown (Exec mode)
if [[ ! -f "$STATE_FILE" ]]; then
    echo "No Alarm"
    exit 0
fi

read start_time raw_timer message < "$STATE_FILE"

# Parse raw_timer to seconds
seconds=0
timer_parse="$raw_timer"
while [[ $timer_parse =~ ([0-9]+)([hms]) ]]; do
    num=${BASH_REMATCH[1]}; unit=${BASH_REMATCH[2]}
    case "$unit" in
        h) seconds=$((seconds + num * 3600)) ;;
        m) seconds=$((seconds + num * 60)) ;;
        s) seconds=$((seconds + num)) ;;
    esac
    timer_parse=${timer_parse/${BASH_REMATCH[0]}/}
done

current_time=$(date +%s)
elapsed=$((current_time - start_time))
remaining=$((seconds - elapsed))

if [ $remaining -le 0 ]; then
    rm "$STATE_FILE"
    notify-send "Alarm" "$message"
    play ~/Documents/communicator.mp3 &
    echo "   Done"
    pkill -RTMIN+8 waybar
else
    printf "   %02dh %02dm %02ds\n" $((remaining / 3600)) $(( (remaining % 3600) / 60 )) $((remaining % 60))
fi
