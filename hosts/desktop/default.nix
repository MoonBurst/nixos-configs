{ config, lib, pkgs, ... }:

{
  networking.hostName = "moonbeauty";

  imports = [
    # System-level modules
    # NOTE: The missing files are commented out to fix the 'path does not exist' error.
    #../../modules/desktop-hardware.nix
    #../../modules/desktop-kernel.nix
    ../../modules/common/default.nix # Imports the base user definition and packages
  ];
  
  # ====================================================================
  #  BOOT AND SYSTEM CONFIGURATION
  # ====================================================================
  
  # Bootloader (systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # --- AMDGPU/ROCm Kernel Parameters ---
  boot.kernelParams = [
    "amdgpu.vm_fragment_size=9"
    "fbcon=rotate:2" #--rotates screen
    "amdgpu.ppfeaturemask=0xffffffff" #--needed for corectrl
    "cma=512M"
  ];
  
  boot.initrd.kernelModules = [ 
    "amdgpu" 
  ];
  
  
  
  # ====================================================================
  # CRON
  # ==================================================================== 
  
  services.cron = {
    enable = false; # Correctly disabled to skip running jobs
    systemCronJobs = [
      #backs up music
      "0 12 * * * ~/scripts/cron_scripts/music-backup.sh >/dev/null 2>&1"
      #backs up passwords
      "0 0 * * 0 ~/scripts/cron_scripts/pass_copy.sh >/dev/null 2>&1"
      #pushes a backup to nextcloud
      "0 4 1 * * ~/scripts/cron_scripts/nextcloud_upload.sh >/dev/null 2>&1"
      #moves .desktop files from home folder to .local/share/applications (mostly for steam games) 
      "0 */4 * * * ~/scripts/cron_scripts/mv-.desktop-to-applications.sh >/dev/null 2>&1"
      #reminders
      "0 */4 * * * ~/scripts/cron_scripts/reminder.sh >/dev/null 2>&1"
      #github update
      "0 0 * * 0 /run/current-system/sw/bin/bash ~/scripts/github/github-updater.sh >> ~/scripts/github-updater.log >/dev/null 2>&1"
      #wallpaper switching
      "*/30 * * * * ~/scripts/cron_scripts/wallpaper.sh >/dev/null 2>&1"
    ];
  };

  services.xserver.enable = true; # <-- SEMICOLON ADDED HERE

  # ... other desktop-only system/user settings
  
  # FIX: Using '++' to append packages to the list from common/default.nix
  environment.systemPackages = config.environment.systemPackages ++ (with pkgs; [
    # --- MB Packages ---
    # The 'cron' package is likely pulled from common/default.nix but harmless here
    rocmPackages.rocm-smi # ROCm GPU monitoring
    corectrl
    gamescope
    mesa
    protonup-qt
    obs-studio
    obs-cli
    mangohud
    openrgb-with-all-plugins
  ]); 
  
  # The final closing brace MUST NOT have a semicolon.
}
