# moonbeauty - Desktop Host Configuration
{
  config,
  pkgs,
  lib,
  niri-flake,
  cypkgs,
  sops-nix,
  ...
}: {
  # ====================================================================
  # MODULE IMPORTS
  # ====================================================================
  imports = [
    ../../hosts/common/default.nix
    ./mounts.nix
  ];
  # ====================================================================
  # SOPS
  # ====================================================================
 sops = {
    defaultSopsFile = ../../secrets.yaml; # Adjust path to find your secrets.yaml
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";

    # This exposes the secret at /run/secrets/sops_key
    secrets.sops_key = { };
  };
  # ====================================================================
  # BORG BACKUP
  # ====================================================================
  services.borgbackup.jobs."MoonBeauty-Backup" = {
  paths = [ "/home/moonburst" ];
  repo = "/mnt/main_backup/";
  startAt = "00:00";
  extraCreateArgs = "--stats --list --filter=AME";  #shows up in journalctl

  # Prune Policy: Keep 7 daily, 4 weekly, and 6 monthly backups
    prune.keep = {
    daily = 7;
    weekly = 4;
    monthly = 6;
  };

  exclude = [
    # Custom Rules
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

    # Trash & Temp
    "*/.local/share/Trash"
    "*/.Trash*"
    "**/.tmp"
    "**/*.swp"
    "**/*.bak"

    # Browser Caches (Simplified patterns)
    "*/.cache/mozilla/firefox"
    "*/.cache/google-chrome"
    "*/.cache/BraveSoftware"
    "*/.config/chromium/*/Service Worker/CacheStorage"

    # Development Artefacts
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


services.borgbackup.jobs."MoonBeauty-Nextcloud" = {
  paths = [ "/home/moonburst" ];
  repo = "/var/lib/borgbackup/nextcloud-staging";
  startAt = "01:00";
   extraCreateArgs = "--stats --list --filter=AME";

   # Prune Policy: Keep 7 daily, 4 weekly, and 6 monthly backups
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
    # Custom Rules
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
    ""
    # Trash & Temp
    "*/.local/share/Trash"
    "*/.Trash*"
    "**/.tmp"
    "**/*.swp"
    "**/*.bak"
    # Browser Caches (Simplified patterns)
    "*/.cache/mozilla/firefox"
    "*/.cache/google-chrome"
    "*/.cache/BraveSoftware"
    "*/.config/chromium/*/Service Worker/CacheStorage"
    # Development Artefacts
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
  # NETWORKING
  # ====================================================================
  networking.hostName = "moonbeauty";

  # ====================================================================
  # SERVICES AND HARDWARE (OpenRGB and Steam)
  # ====================================================================
  # OPENRGB STUFF
  services.hardware.openrgb.enable = true;
  hardware.i2c.enable = true;

  # STEAM STUFF
programs.gamescope.capSysNice = true;
programs.gamemode.enable = true;
hardware.steam-hardware.enable = true;
programs.steam.enable = true;
programs.steam.dedicatedServer.openFirewall = true;
#VM STUFF
virtualisation.libvirtd.enable = true;
programs.virt-manager.enable = true;
systemd.tmpfiles.rules = [
  "f /dev/shm/looking-glass 0660 moonburst qemu-libvirtd -"
];
services.udev.extraRules = ''
  SUBSYSTEM=="kvmfr", OWNER="moonburst", GROUP="kvm", MODE="0660"
'';

  # ====================================================================
  # CRON JOBS
  # ====================================================================
  services.cron = {
    enable = true;
    systemCronJobs = [
      # backs up music
#      "0 12 * * * moonburst ~/scripts/cron_scripts/music-backup.sh"
      # backs up passwords
#      "0 0 * * 0 moonburst ~/scripts/cron_scripts/pass_copy.sh"
      # pushes a backup to nextcloud
#  #     "0 4 1 * * moonburst ~/scripts/cron_scripts/nextcloud_upload.sh"
      # moves .desktop files from home folder to .local/share/applications (mostly for steam games)
      "0 */4 * * * moonburst ~/scripts/cron_scripts/mv-.desktop-to-applications.sh"
      # reminders
      "0 */4 * * * moonburst ~/scripts/cron_scripts/reminder.sh"
      # github update
#      "0 0 * * 0 /run/current-system/sw/bin/bash ~/scripts/github/github-updater.sh >> ~/scripts/github-updater.log >/dev/null 2>&1"
      # wallpaper switching
      "*/30 * * * * moonburst ~/scripts/cron_scripts/wallpaper.sh "
    ];
  };


  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  environment.systemPackages = with pkgs; [
    # --- Custom Flake Packages (from overlay in flake.nix) ---

    # --- System Utilities/Shell ---
    cron
    rocmPackages.rocm-smi
    corectrl
    wget
    curl
    openrgb-with-all-plugins
    # --- Gaming/GPU/Emulation ---
    gamescope#for steam
    mesa#GPU driverrs
    protonup-qt#for steam
    obs-studio#obs
    obs-cli#obs
    mangohud#system use/FPS counter
    # --- Desktop/Theming ---
    krita#image editor
kdePackages.partitionmanager#partition manager

cura-appimage#3d printer
openscad#3d printer
orca-slicer#3d printer
nicotine-plus#music downloader
jami#chat client
vicinae#launcher
dnsmasq#VM related
looking-glass-client#VM related
borgbackup
    ];

  system.stateVersion = "25.11";
}
