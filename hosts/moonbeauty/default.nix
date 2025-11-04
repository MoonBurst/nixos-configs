# moonbeauty - Desktop Host Configuration
{ config, pkgs, lib, local-packages, niri-flake, ... }:

{
  # ====================================================================
  # MODULE IMPORTS
  # ====================================================================
  imports = [
    ../../hosts/moonbeauty-hardware.nix
    # ../../modules/common/default.nix
    ./mounts.nix
  ];

  # ====================================================================
  # NETWORKING
  # ====================================================================
  networking.hostName = "moonbeauty";

  # Set your time zone
  time.timeZone = "America/Chicago";

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
  
  # ====================================================================
  # CRON JOBS
  # ====================================================================  
  services.cron = {
    enable = false; # Set to true when ready to activate these jobs
    systemCronJobs = [
      # backs up music
      "0 12 * * * ~/scripts/cron_scripts/music-backup.sh >/dev/null 2>&1"
      # backs up passwords
      "0 0 * * 0 ~/scripts/cron_scripts/pass_copy.sh >/dev/null 2>&1"
      # pushes a backup to nextcloud
      "0 4 1 * * ~/scripts/cron_scripts/nextcloud_upload.sh >/dev/null 2>&1"
      # moves .desktop files from home folder to .local/share/applications (mostly for steam games) 
      "0 */4 * * * ~/scripts/cron_scripts/mv-.desktop-to-applications.sh >/dev/null 2>&1"
      # reminders
      "0 */4 * * * ~/scripts/cron_scripts/reminder.sh >/dev/null 2>&1"
      # github update
      "0 0 * * 0 /run/current-system/sw/bin/bash ~/scripts/github/github-updater.sh >> ~/scripts/github-updater.log >/dev/null 2>&1"
      # wallpaper switching
      "*/30 * * * * ~/scripts/cron_scripts/wallpaper.sh  >/dev/null 2>&1"
    ];
  };

  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  environment.systemPackages = with pkgs; [
    # --- Custom Flake Packages (from overlay in flake.nix) ---
    sherlock-launcher
    fchat-horizon
    
    # --- System Utilities/Shell ---
    cron
    rocmPackages.rocm-smi 
    corectrl
    wget
    curl
    # --- Gaming/GPU/Emulation ---
    gamescope
    mesa
    protonup-qt 
    obs-studio
    obs-cli
    mangohud
    # --- Desktop/Theming ---
    openrgb-with-all-plugins
  ];

  # Niri Wayland Compositor (Restoring the intended configuration)
  programs.niri = {
    enable = true;
    package = niri-flake.packages.${pkgs.system}.niri;
  };

  # Define all users in your system
  users.users.moonburst = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  # Essential settings
  system.stateVersion = "25.11"; # Keep this set to your desired version
}
