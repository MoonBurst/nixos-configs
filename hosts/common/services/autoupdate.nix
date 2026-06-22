{ config, pkgs, lib, ... }:

let
  # Stable user detection: Primary target -> First normal user -> root fallback
  targetUser =
    if builtins.hasAttr "moonburst" config.users.users then "moonburst"
    else
      let
        normalUsers = builtins.attrNames (lib.filterAttrs (n: v: v.isNormalUser) config.users.users);
      in if normalUsers != [] then builtins.head normalUsers else "root";

  # Fixed hook using /run/wrappers/bin/su for proper permissions and pathing
  preUpgradeScript = pkgs.writeScript "pre-upgrade-hook" ''
    #!${pkgs.runtimeShell}
    # 1. Update root channels
    ${pkgs.nix}/bin/nix-channel --update

    # 2. Update user channels if targetUser isn't root
    if [ "${targetUser}" != "root" ]; then
      echo "Updating channels for ${targetUser}..."
      /run/wrappers/bin/su - ${targetUser} -c '${pkgs.nix}/bin/nix-channel --update' || true
    fi
  '';
in
{
  system.autoUpgrade = {
    enable = true;
    flake = "path:/home/${targetUser}/nix#${config.networking.hostName}";
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "nixpkgs-unstable"
    ];
    dates = "weekly";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  # Execute the pre-upgrade script with full privileges
  systemd.services.nixos-upgrade.serviceConfig.ExecStartPre = [
    "!${preUpgradeScript}"
  ];

  systemd.services."notify-update-failure" = {
    description = "Capture logs and send critical desktop notification on upgrade failure";
    script = ''
      LOG_FILE="/home/${targetUser}/UPDATE_FAILED.txt"
      USER_NAME="${targetUser}"
      USER_ID=$(id -u "$USER_NAME")

      echo "--- NIXOS AUTO-UPDATE FAILED ON $(date) ---" > "$LOG_FILE"
      ${pkgs.systemd}/bin/journalctl -u nixos-upgrade.service -n 100 --no-pager >> "$LOG_FILE"

      # Ensure permissions allow the user to read the log
      chown "$USER_NAME":users "$LOG_FILE" || true

      # Check if User D-Bus is available for notifications
      if [ -S "/run/user/$USER_ID/bus" ]; then
        ${pkgs.systemd}/bin/systemd-run \
          --user --machine="$USER_NAME@.host" \
          ${pkgs.libnotify}/bin/notify-send -u critical \
          "SYSTEM UPDATE FAILED" \
          "Logs saved to $LOG_FILE"
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  # Trigger the notification only if the upgrade fails
  systemd.services.nixos-upgrade.unitConfig.OnFailure = "notify-update-failure.service";

  # Clean up the error log if the service eventually succeeds
  systemd.services.nixos-upgrade.postStop = ''
    if [ "$SERVICE_RESULT" = "success" ]; then
      rm -f /home/${targetUser}/UPDATE_FAILED.txt
    fi
  '';
}
