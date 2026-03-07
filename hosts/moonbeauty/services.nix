{ config, pkgs, lib, ... }:

{
  # ====================================================================
  # BORG BACKUP JOB: MoonBeauty-Backup
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
      passCommand = "cat ${config.sops.secrets.moonburst_password.path}";
    };
  };

  # ====================================================================
  # BORG BACKUP JOB: MoonBeauty-Nextcloud
  # ====================================================================
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

    exclude = [
      "*/.steam" "*/.cache" "*/.config/sops" "*/.config/vesktop/sessionData"
      "*/.config/horizon-electron/Partitions" "*/.var" "*/.local/share/cargo"
      "*/.local/share/Steam" "*/.lmstudio" "*/.git/objects" "*/Games"
      "*/stump_backup.tar.gz" "*/.local/share/Trash" "*/.Trash*" "**/.tmp"
      "**/*.swp" "**/*.bak" "*/.cache/mozilla/firefox" "*/.cache/google-chrome"
      "*/.cache/BraveSoftware" "*/.config/chromium/*/Service Worker/CacheStorage"
      "**/node_modules" "**/.npm" "**/__pycache__" "**/.venv" "**/.cargo"
      "**/.rustup" "**/.gradle"
    ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.moonburst_password.path}";
    };
  };

  # Borg System Overrides
  systemd.services."borgbackup-job-MoonBeauty-Backup" = {
    restartIfChanged = false;
    stopIfChanged = false;
  };

  systemd.services."borgbackup-job-MoonBeauty-Nextcloud" = {
    restartIfChanged = false;
    stopIfChanged = false;
  };
}
