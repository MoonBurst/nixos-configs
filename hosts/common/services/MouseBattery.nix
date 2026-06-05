{ pkgs, ... }:

{
  systemd.services.check-mouse-battery = {
    description = "Check ASUS ROG Mouse Battery Level";
    path = [ pkgs.hidapitester pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.libnotify pkgs.findutils ];
    script = ''
      # Query the mouse via the verified 12 04 registration command
      HEX_OUTPUT=$(hidapitester --vidpid 0b05:1a72 --open --length 64 --send-output 0x12,0x04,0x00,0x00 --read-input 2>/dev/null)
      
      # Isolate the data response payload line
      DATA_LINE=$(echo "$HEX_OUTPUT" | grep -A 1 "read 64 bytes:" | tail -n 1)

      # Check if the output report line is completely missing or empty due to a timeout
      if [ -z "$DATA_LINE" ]; then
        echo "Mouse is currently sleeping or disconnected. Skipping check."
        exit 0
      fi

      # Verify the payload structure starts with the expected ASUS signature header
      # If it returns generic zeroes or a disconnected signature, exit silently
      if [[ ! "$DATA_LINE" == *"12 04"* ]]; then
        echo "Mouse returned idle/handshake padding instead of data. Skipping check."
        exit 0
      fi

      # Parse the 13th byte and forcefully strip all hidden trailing/leading spaces
      BATTERY_TIER=$(echo "$DATA_LINE" | awk '{print $13}' | tr -d '[:space:]')

      # Safety fallback if the parsed string variable evaluates to empty
      if [ -z "$BATTERY_TIER" ]; then
        echo "Failed to parse battery tier token. Skipping check."
        exit 0
      fi

      # Function to send notify-send alerts from root to the active graphical session
      send_notification() {
        local urgency="$1"
        local icon="$2"
        local title="$3"
        local message="$4"
        
        # Discover the active desktop user and their corresponding DBUS address
        local USER_ID=$(id -u moonburst)
        export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
        
        if [ -S "/run/user/$USER_ID/bus" ]; then
          # Execute notify-send inside the user's graphical environment
          ${pkgs.sudo}/bin/sudo -u moonburst DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS \
            ${pkgs.libnotify}/bin/notify-send -u "$urgency" -i "$icon" "$title" "$message"
        fi
      }

      # Map the verified hardware responses
      case "$BATTERY_TIER" in
        "03")
          echo "Mouse status: Battery High / Full (Tier 3)"
          # Silent when full - No desktop notification sent
          ;;
        "02")
          echo "Mouse status: Battery Medium (Tier 2)"
          # Silent when fine - No desktop notification sent
          ;;
        "01")
          echo "Mouse status: Battery Low (Tier 1)"
          send_notification "normal" "battery-low" "Mouse Battery Low" "Your mouse is running low (Tier 1). Below 25%"
          ;;
        "00")
          echo "Mouse status: Battery Critical / Connect Cable (Tier 0)"
          send_notification "critical" "battery-empty" "Mouse Battery Critical!" "Your mouse is low on power (Tier 0). Below 10%"
          ;;
        *)
          echo "Mouse status: Dropped packet or alternate frame state [$BATTERY_TIER]"
          ;;
      esac
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.check-mouse-battery = {
    description = "Trigger mouse battery check every 10 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "10m";
      AccuracySec = "1s";
    };
  };
}
