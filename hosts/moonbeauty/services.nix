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
      "*/.steam"
      "*/.cache"
      "*/.config/sops"
      "*/.config/vesktop/sessionData"
      "*/.config/horizon-electron/Partitions"
      "*/.var"
      "*/.local/share/cargo"
      "*/.local/share/Steam"
      "*/.lmstudio"
      "*/.git/objects"
      "*/Games"
      "*/.local/share/Trash"
      "*/.Trash*"
      "**/.tmp"
      "**/*.swp"
      "**/*.bak"
      "*/.cache/mozilla/firefox"
      "*/.cache/google-chrome"
      "*/.cache/BraveSoftware"
      "*/.config/chromium/*/Service Worker/CacheStorage"
      "**/node_modules"
      "**/.npm"
      "**/__pycache__"
      "**/.venv"
      "**/.cargo"
      "**/.rustup"
      "**/.gradle"
    ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.sops_key.path}";
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
      "*/.steam"
      "*/.cache"
      "*/.config/sops"
      "*/.config/vesktop/sessionData"
      "*/.config/horizon-electron/Partitions"
      "*/.var"
      "*/.local/share/cargo"
      "*/.local/share/Steam"
      "*/.lmstudio"
      "*/.git/objects"
      "*/Games"
      "*/stump_backup.tar.gz"
      "*/.local/share/Trash"
      "*/.Trash*"
      "**/.tmp"
      "**/*.swp"
      "**/*.bak"
      "*/.cache/mozilla/firefox"
      "*/.cache/google-chrome"
      "*/.cache/BraveSoftware"
      "*/.config/chromium/*/Service Worker/CacheStorage"
      "**/node_modules"
      "**/.npm"
      "**/__pycache__"
      "**/.venv"
      "**/.cargo"
      "**/.rustup"
      "**/.gradle"
    ];

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets.sops_key.path}";
    };
  };

  # ====================================================================
  # SYSTEMD SYSTEM OVERRIDES
  # ====================================================================
  systemd.services."borgbackup-job-MoonBeauty-Backup" = {
    restartIfChanged = false;
    stopIfChanged = false;
  };

  systemd.services."borgbackup-job-MoonBeauty-Nextcloud" = {
    restartIfChanged = false;
    stopIfChanged = false;
  };

  # ====================================================================
  # SYSTEMD USER TIMERS & SERVICES
  # ====================================================================

  # --- 1. Desktop File Mover ---
  systemd.user.services.move-desktop-files = {
    description = "Move .desktop files from home to applications folder";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash ${./scripts/mv-.desktop-to-applications.sh}";
  };

  # --- 2. Reminders ---
  systemd.user.services.reminders = {
    description = "Run desktop reminder script";
    path = with pkgs; [ bash zenity libnotify coreutils ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/reminder.sh}";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR";
    };
  };

  # --- 3. Wallpaper Switcher ---
  systemd.user.services.wallpaper-switcher = {
    description = "Switch desktop wallpaper every 30 minutes";
    # Added sway here so swaymsg is found
    path = with pkgs; [ bash sway swaybg coreutils gnused gnugrep ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/wallpaper.sh}";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR";
    };
  };
}
