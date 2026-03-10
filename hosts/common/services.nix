{ config, pkgs, lib, ... }:

{
   # --- Display & Desktop Services ---
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };
  services.dbus.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;

  # --- SMART Disk Monitoring ---
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

  # --- XDG Portals ---
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

  # --- Auto Upgrades ---
  system.autoUpgrade = {
    enable = true;
    flake = "path:/home/moonburst/nix#${config.networking.hostName}";
    flags = [ "--update-input" "nixpkgs" ];
    dates = "11:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  systemd.services."notify-update-failure" = {
    description = "Capture logs and send critical desktop notification on upgrade failure";
    script = ''
      LOG_FILE="/home/moonburst/UPDATE_FAILED.txt"
      USER_NAME="moonburst"
      USER_ID=$(id -u "$USER_NAME")
      echo "--- NIXOS AUTO-UPDATE FAILED ON $(date) ---" > "$LOG_FILE"
      /run/current-system/sw/bin/journalctl -u nixos-upgrade.service -n 100 --no-pager >> "$LOG_FILE"
      chown "$USER_NAME":users "$LOG_FILE"
      if [ -S "/run/user/$USER_ID/bus" ]; then
        /run/current-system/sw/bin/systemd-run \
          --user --machine="$USER_NAME@.host" \
          /run/current-system/sw/bin/notify-send -u critical \
          "SYSTEM UPDATE FAILED" \
          "Logs saved to $LOG_FILE"
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nixos-upgrade.unitConfig.OnFailure = "notify-update-failure.service";
  systemd.services.nixos-upgrade.postStop = ''
    if [ "$SERVICE_RESULT" = "success" ]; then
      rm -f /home/moonburst/UPDATE_FAILED.txt
    fi
  '';

  # --- Greetd / Tuigreet Configuration ---
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd sway";
        user = "greeter";
      };
    };
  };
systemd.services.greetd.serviceConfig = {
  Type = "idle";
  StandardInput = "tty";
  StandardOutput = "tty";
  StandardError = "journal"; # Keeps the UI clean
  TTYReset = true;
  TTYVHangup = true;
  TTYVTDisallocate = true;
};
  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter - -"
  ];
}
