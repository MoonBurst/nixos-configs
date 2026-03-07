{ config, pkgs, lib, ... }:

{
  # --- Display & Desktop Services ---
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };
  services.dbus.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.displayManager.ly.enable = false;

  # --- System & Storage Services ---
  services.openssh = {
    enable = true;
    authorizedKeysFiles = [
      "/etc/ssh/authorized_keys.d/%u_laptop"
      "/etc/ssh/authorized_keys.d/%u_desktop"
    ];
  };

  services.gvfs.enable = true;
  services.journald.extraConfig = "SystemMaxUse=1G;";
  programs.sway.enable = true;
  environment.variables.TERMINAL = "kitty";
  nix.settings.trusted-users = [ "root" "moonburst" "lunarchild" ];

  # --- Borg Backup (Hostname Specific) ---
  # This ensures the desktop jobs only run on moonbeauty
  services.borgbackup.jobs = lib.mkIf (config.networking.hostName == "moonbeauty") {
    "MoonBeauty-Backup" = {
      paths = [ "/home/moonburst" ];
      repo = "/mnt/main_backup/";
      encryption = {
        mode = "repokey-blake2";
        # UPDATED: Changed sops_key to master_password to match security.nix
        passCommand = "cat ${config.sops.secrets.master_password.path}";
      };
      compression = "auto,zstd";
      startAt = "daily";
    };
  };

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
    flake = "path:/home/moonburst/nixos-config#${config.networking.hostName}";
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

  # FIX: Create cache directory so tuigreet can actually "remember" the user
  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter - -"
  ];

  # --- Home Manager ---
  home-manager = {
    backupFileExtension = "backup";
    users.moonburst = { pkgs, ... }: {
      home.packages = [ pkgs.cliphist pkgs.wl-clipboard ];
      systemd.user.services = {
        cliphist-text = {
          Unit.Description = "Clipboard text history manager";
          Service.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50";
          Install.WantedBy = [ "graphical-session.target" ];
        };
        cliphist-images = {
          Unit.Description = "Clipboard image history manager";
          Service.ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10";
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
      home.stateVersion = "25.11";
    };
  };

  # ====================================================================
  # SHARED DESKTOP SERVICES
  # ====================================================================

  systemd.user.services.move-desktop-files = {
    description = "Move .desktop files from home to applications folder";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash ${./scripts/mv-.desktop-to-applications.sh}";
  };

  systemd.user.services.reminders = {
    description = "Run desktop reminder script";
    path = with pkgs; [ bash zenity libnotify coreutils ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/reminder.sh}";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR";
    };
  };

  systemd.user.services.wallpaper-switcher = {
    description = "Switch desktop wallpaper every 30 minutes";
    path = with pkgs; [ bash sway swaybg coreutils gnused gnugrep ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/wallpaper.sh}";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR";
    };
  };

  systemd.services.watch-cinny = {
    description = "Check live NixOS 25.11 branch for Cinny updates";
    path = [ pkgs.nix pkgs.cacert pkgs.gnugrep pkgs.libnotify pkgs.coreutils ];
    script = ''
      CURRENT="4.10.3"
      REMOTE=$(nix eval --raw "github:NixOS/nixpkgs/nixos-25.11#cinny-desktop.version" --extra-experimental-features "nix-command flakes" 2>/dev/null)
      if [ -z "$REMOTE" ]; then exit 0; fi
      NEWER=$(printf "%s\n%s" "$CURRENT" "$REMOTE" | sort -V | tail -n1)
      if [ "$NEWER" == "$REMOTE" ] && [ "$REMOTE" != "$CURRENT" ]; then
        notify-send "Cinny Update" "Stable 25.11 now has $REMOTE" -u critical
      fi
    '';
    serviceConfig = { Type = "oneshot"; User = "moonburst"; };
    environment = { DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus"; };
  };

  systemd.timers.watch-cinny = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "hourly"; Persistent = true; };
  };
}
