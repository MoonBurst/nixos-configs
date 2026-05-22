#!/usr/bin/env bash
# Author: Ruben Lopez (Logon84) <rubenlogon@yahoo.es> (Fixed by AI helper)
# Description: Cleaned script using robust regex to target raw WirePlumber ID mapping layouts

SINKS_TO_SKIP="other_sink_name1|Blue_Microphones|iec958-stereo"

# 1. Grab all clean Sink ID numbers from the wpctl Sinks section block
ALL_SINKS=($(wpctl status | sed -n '/Sinks:/,/^$/p' | grep -E '^[[:space:]]*[*[:space:]][[:space:]]*[0-9]+\.' | grep -Ev "$SINKS_TO_SKIP" | sed -E 's/^[[:space:]]*[*[:space:]][[:space:]]*([0-9]+)\..*/\1/'))
TOTAL_ELEMENTS=${#ALL_SINKS[@]}

if [ "$TOTAL_ELEMENTS" -le 1 ]; then
    echo "Only 1 available audio device detected. Skipping toggle pass."
    exit 0
fi

# 2. Isolate the exact ID number that has the active '*' pointer marker flag
ACTIVE_ID=$(wpctl status | sed -n '/Sinks:/,/^$/p' | grep -E '^[[:space:]]*\*' | sed -E 's/^[[:space:]]*\*[[:space:]]*([0-9]+)\..*/\1/')

# 3. Step through the array indices to find where the active path sits
ACTIVE_INDEX=-1
for i in "${!ALL_SINKS[@]}"; do
   if [ "${ALL_SINKS[$i]}" "${ACTIVE_ID}" ]; then
       ACTIVE_INDEX=$i
       break
   fi
done

# 4. Cycle to the next array index position cleanly
NEXT_INDEX=$(( (ACTIVE_INDEX + 1) % TOTAL_ELEMENTS ))
NEXT_SINK_ID=${ALL_SINKS[$NEXT_INDEX]}

# 5. Execute switch default rule pass
wpctl set-default "$NEXT_SINK_ID"
/run/current-system/sw/bin/notify-send "Audio Switcher" "Switched default output sink endpoint to ID: $NEXT_SINK_ID" --icon=audio-speakers
