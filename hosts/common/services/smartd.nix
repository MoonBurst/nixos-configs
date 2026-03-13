{ pkgs, ... }:

{
  services.smartd = {
    enable = true;
    defaults.monitored = ''
      -a -o on -S on -n standby,q -s (S/../.././02) -M exec ${
        let
          notifyScript = pkgs.writeShellScript "smartd-notify" ''
            for bus in /run/user/*/bus; do
              if [ -S "$bus" ]; then
                UID_NUM=$(echo "$bus" | cut -d'/' -f4)
                USER_NAME=$(id -nu "$UID_NUM")
                USER_DISPLAY=$(grep -z '^DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')
                USER_WAYLAND=$(grep -z '^WAYLAND_DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')
                ${pkgs.sudo}/bin/sudo -u "$USER_NAME" \
                  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
                  DISPLAY="$USER_DISPLAY" \
                  WAYLAND_DISPLAY="$USER_WAYLAND" \
                  ${pkgs.libnotify}/bin/notify-send -u critical \
                  "SMART Disk Alert" "$SMARTD_MESSAGE"
              fi
            done
          '';
        in "${notifyScript}"
      }
    '';
  };
}
