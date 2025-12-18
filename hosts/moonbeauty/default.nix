# moonbeauty - Desktop Host Configuration
{
  config,
  pkgs,
  lib,
  niri-flake,
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
  hardware.steam-hardware.enable = true;
  programs.gamemode.enable = true;
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
    package = pkgs.steam.override {
      extraArgs = "gamescope -W 2560 -H 1440 -r 165 --adaptive-sync --force-grab-cursor --rt --backend wayland  --immediate --%command%";
    };
    gamescopeSession.enable = true;
  };

  # ====================================================================
  # CRON JOBS
  # ====================================================================
  services.cron = {
    enable = true;
    systemCronJobs = [
      # backs up music
      "0 12 * * * moonburst ~/scripts/cron_scripts/music-backup.sh"
      # backs up passwords
      "0 0 * * 0 moonburst ~/scripts/cron_scripts/pass_copy.sh"
      # pushes a backup to nextcloud
      "0 4 1 * * moonburst ~/scripts/cron_scripts/nextcloud_upload.sh"
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
    # --- Gaming/GPU/Emulation ---
    mesa
    protonup-qt
    obs-studio
    obs-cli
    mangohud
    # --- Desktop/Theming ---
    openrgb-with-all-plugins
    lmstudio
    krita
    cura-appimage
    kdePackages.partitionmanager
openscad
orca-slicer
nicotine-plus
jami
edopro

    ];

  system.stateVersion = "25.11";
}
