{ pkgs, ... }:

{
  systemd.services.check-mouse-battery = {
    description = "Check ASUS ROG Mouse Battery Level";
    path = [ pkgs.hidapitester pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.libnotify pkgs.findutils pkgs.sudo ];
    script = ''
      # Query the mouse via the verified 12 04 battery command (with safe fallback if disconnected)
      HEX_OUTPUT=$(hidapitester --vidpid 0b05:1a72 --open --length 64 --send-output 0x12,0x04,0x00,0x00 --read-input 2>/dev/null || echo "ERROR")

      if [ "$HEX_OUTPUT" = "ERROR" ] || [ -z "$HEX_OUTPUT" ]; then
        echo "Mouse is currently disconnected or failed to open. Skipping check."
        exit 0
      fi

      # Isolate the read response block (only lines that appear after the "Read" indicator)
      READ_BLOCK=$(echo "$HEX_OUTPUT" | awk '/[Rr]ead/ {flag=1; next} flag' || true)

      # Clean up "0x" prefixes and commas to get a pure, space-separated hex string
      CLEANED_BLOCK=$(echo "$READ_BLOCK" | sed 's/0x//g' | sed 's/,//g' | tr -d '\r' || true)

      # Extract ONLY the raw hex line that starts with "12 04"
      RAW_HEX_LINE=$(echo "$CLEANED_BLOCK" | grep -iE '^[[:space:]]*12[[:space:]]+04' | xargs || true)

      if [ -z "$RAW_HEX_LINE" ]; then
        echo "Mouse did not return a valid 12 04 battery payload. Skipping check."
        exit 0
      fi

      # Log raw clean hex data to systemd journal for debugging
      echo "Cleaned mouse response payload: $RAW_HEX_LINE"

      # Parse Column 14 (Charging status) and Column 15 (Battery Level Tier)
      CHARGING_STATUS=$(echo "$RAW_HEX_LINE" | awk '{print $14}' | tr -d '[:space:]')
      BATTERY_TIER=$(echo "$RAW_HEX_LINE" | awk '{print $15}' | tr -d '[:space:]')

      # Validate that we got a clean tier string
      if [ -z "$BATTERY_TIER" ]; then
        echo "No battery tier found in response. Skipping check."
        exit 0
      fi

      send_notification() {
        local urgency="$1"
        local icon="$2"
        local title="$3"
        local message="$4"

        local USER_ID=$(id -u moonburst)

        # Define display environment variables for root to access user graphical session
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
        export DISPLAY=":0"
        export XAUTHORITY="/home/moonburst/.Xauthority"

        if [ -S "/run/user/$USER_ID/bus" ]; then
          sudo -u moonburst \
            DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
            DISPLAY="$DISPLAY" \
            XAUTHORITY="$XAUTHORITY" \
            notify-send -u "$urgency" -i "$icon" "$title" "$message"
        fi
      }

      # Map battery tiers to a descriptive message string
      case "$BATTERY_TIER" in
        "03")
          HUMAN_POWER="High / Full (~75% - 100%)"
          URGENCY="normal"
          ICON="battery-full"
          ;;
        "02")
          HUMAN_POWER="Medium (~25% - 75%)"
          URGENCY="normal"
          ICON="battery-good"
          ;;
        "01")
          HUMAN_POWER="Low (~10% - 25%)"
          URGENCY="critical"
          ICON="battery-caution"
          ;;
        "00")
          HUMAN_POWER="Critical (<10%)"
          URGENCY="critical"
          ICON="battery-low"
          ;;
        *)
          HUMAN_POWER="Unknown State [$BATTERY_TIER]"
          URGENCY="normal"
          ICON="battery-missing"
          ;;
      esac

      # Append charging status if byte 13 (Column 14) is active (01)
      if [ "$CHARGING_STATUS" = "01" ]; then
        HUMAN_POWER="$HUMAN_POWER [Charging ⚡]"
      fi

      # Log cleanly to systemd journal
      echo "Current Evaluated Mouse Power: $HUMAN_POWER"

      # Trigger alert on Tier 2 (to catch low states early), Tier 1, or Tier 0 when not charging
      if { [ "$BATTERY_TIER" = "02" ] || [ "$BATTERY_TIER" = "01" ] || [ "$BATTERY_TIER" = "00" ]; } && [ "$CHARGING_STATUS" != "01" ]; then
        send_notification "$URGENCY" "$ICON" "Mouse Battery Check" "Your mouse reports: $HUMAN_POWER"
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.check-mouse-battery = {
    description = "Trigger mouse battery check every X minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "60m";
      AccuracySec = "1s";
    };
  };
}
