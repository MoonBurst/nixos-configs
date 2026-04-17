#!/run/current-system/sw/bin/bash

# 1. Toggle the default source
/run/current-system/sw/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# 2. Check volume status (more consistent than get-mute)
# This will output something like "Volume: 0.50 [MUTED]" or just "Volume: 0.50"
MUTE_CHECK=$(/run/current-system/sw/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

# 3. Use an explicit string match
if [[ "$MUTE_CHECK" == *"[MUTED]"* ]]; then
    /run/current-system/sw/bin/notify-send "Microphone" "OFF" \
        -i microphone-sensitivity-muted-symbolic \
        -h string:x-dunst-stack-tag:mic_state
else
    /run/current-system/sw/bin/notify-send "Microphone" "ON" \
        -i microphone-sensitivity-high-symbolic \
        -h string:x-dunst-stack-tag:mic_state
fi
