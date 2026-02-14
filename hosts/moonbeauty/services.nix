{ config, pkgs, ... }:

{
  # ====================================================================
  # SYSTEMD USER TIMERS & SERVICES
  # ====================================================================

    # --- 1. Desktop File Mover ---
  systemd.user.services.move-desktop-files = {
    description = "Move .desktop files from home to applications folder";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /home/moonburst/scripts/cron_scripts/mv-.desktop-to-applications.sh";
  };
  systemd.user.timers.move-desktop-files = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "00,04,08,12,16,20:00:00"; # Simplified: Every 4 hours
      Persistent = true;
    };
  };

  # --- 2. Reminders ---
  systemd.user.services.reminders = {
    description = "Run desktop reminder script";
    path = with pkgs; [ bash zenity libnotify coreutils ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash /home/moonburst/scripts/cron_scripts/reminder.sh";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR";
    };
  };
  systemd.user.timers.reminders = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "00,04,08,12,16,20:00:00"; # Simplified: Every 4 hours
      Persistent = true;
    };
  };


  # ====================================================================
  # BORG BACKUP
  # ====================================================================
  services.borgbackup.jobs."MoonBeauty-Backup" = {
    paths = [ "/home/moonburst" ];
    repo = "/mnt/main_backup/";
    startAt = "00:00";
    extraCreateArgs = "--stats --list --filter=AME";

    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };

    exclude = [
      "*/.steam" "*/.cache" "*/.config/sops" "*/.config/vesktop/sessionData"
      "*/.config/horizon-electron/Partitions" "*/.var" "*/.local/share/cargo"
      "*/.local/share/Steam" "*/.lmstudio" "*/.git/objects" "*/Games"
      "*/.local/share/Trash" "*/.Trash*" "**/.tmp" "**/*.swp" "**/*.bak"
      "*/.cache/mozilla/firefox" "*/.cache/google-chrome" "*/.cache/BraveSoftware"
      "*/.config/chromium/*/Service Worker/CacheStorage" "**/node_modules"
      "**/.npm" "**/__pycache__" "**/.venv" "**/.cargo" "**/.rustup" "**/.gradle"
    ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.sops_key.path}";
    };
  };

  services.borgbackup.jobs."MoonBeauty-Nextcloud" = {
    paths = [ "/home/moonburst" ];
    repo = "/var/lib/borgbackup/nextcloud-staging";
    startAt = "01:00";
    extraCreateArgs = "--stats --list --filter=AME";

    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
    };

    preHook = ''
      mkdir -p /var/lib/borgbackup/nextcloud-staging
    '';
    postHook = ''
      echo "Syncing local Borg repo to Nextcloud (High-Stability Mode)..."
      ${pkgs.rclone}/bin/rclone sync /var/lib/borgbackup/nextcloud-staging NextCloud:backups \
        --config /home/moonburst/.config/rclone/rclone.conf \
        --verbose \
        --transfers 1 \
        --webdav-nextcloud-chunk-size 10M \
        --low-level-retries 20
    '';
    exclude = [
      "*/.steam" "*/.cache" "*/.config/sops" "*/.config/vesktop/sessionData"
      "*/.config/horizon-electron/Partitions" "*/.var" "*/.local/share/cargo"
      "*/.local/share/Steam" "*/.lmstudio" "*/.git/objects" "*/Games"
      "*/stump_backup.tar.gz" "" "*/.local/share/Trash" "*/.Trash*"
      "**/.tmp" "**/*.swp" "**/*.bak" "*/.cache/mozilla/firefox"
      "*/.cache/google-chrome" "*/.cache/BraveSoftware"
      "*/.config/chromium/*/Service Worker/CacheStorage" "**/node_modules"
      "**/.npm" "**/__pycache__" "**/.venv" "**/.cargo" "**/.rustup" "**/.gradle"
    ];
    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.sops_key.path}";
    };
  };
}
