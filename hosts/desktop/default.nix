{ config, lib, pkgs, ... }:

{
  networking.hostName = "moonbeauty";

  imports = [
    # Assuming this file was created and contains fileSystems and boot config
    ../../modules/desktop-hardware.nix
    #../../modules/desktop-kernel.nix
    ../../modules/common/default.nix # Imports the base user definition and packages
  ];
  
  # NOTE: The BOOT AND SYSTEM CONFIGURATION block was removed here
  # and moved to desktop-hardware.nix

  # ====================================================================
  # CRON
  # ==================================================================== 
  
  services.cron = {
    enable = false; # Correctly disabled
    systemCronJobs = [
      # NOTE: These paths are system-level and may still fail unless fully absolute
      "0 12 * * * ~/scripts/cron_scripts/music-backup.sh >/dev/null 2>&1"
      "0 0 * * 0 ~/scripts/cron_scripts/pass_copy.sh >/dev/null 2>&1"
      "0 4 1 * * ~/scripts/cron_scripts/nextcloud_upload.sh >/dev/null 2>&1"
      "0 */4 * * * ~/scripts/cron_scripts/mv-.desktop-to-applications.sh >/dev/null 2>&1"
      "0 */4 * * * ~/scripts/cron_scripts/reminder.sh >/dev/null 2>&1"
      "0 0 * * 0 /run/current-system/sw/bin/bash ~/scripts/github/github-updater.sh >> ~/scripts/github-updater.log >/dev/null 2>&1"
      "*/30 * * * * ~/scripts/cron_scripts/wallpaper.sh >/dev/null 2>&1"
    ];
  };

  services.xserver.enable = true; 

  # ... other desktop-only system/user settings
  
  # CRITICAL FIX: Removed 'config.environment.systemPackages ++'
  # Nix will automatically merge this list with the one from common/default.nix.
  environment.systemPackages = with pkgs; [
    # --- MB Packages ---
    rocmPackages.rocm-smi # ROCm GPU monitoring
    corectrl
    gamescope
    mesa
    protonup-qt
    obs-studio
    obs-cli
    mangohud
    openrgb-with-all-plugins
  ]; # <--- The list is just defined here and automatically merged.
  
  # No extra closing brace or semicolon needed.
}
