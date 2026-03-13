{ config, pkgs, ... }:

{
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
}
