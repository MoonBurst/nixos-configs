{ config, pkgs, lib, ... }:



#=====================================
{
  # ====================================================================
  #  MODULE IMPORTS
  # ====================================================================
  imports = [
    ../../modules/desktop-hardware.nix 
    ../../modules/common/default.nix #Packages on both laptop and desktop
    ./mounts.nix
  ];

#nixpkgs.overlays = [
#    (self: super: {
#      # Use the packages from the my-packages set
#      fchat-horizon = my-packages.fchat-horizon; 
#	moon-burst-theme = super.callPackage ./moonburst-theme.nix {};
#      
#    })
#  ];
  # ====================================================================
  # NETWORKING
  # ====================================================================
  networking.hostName = "moonbeauty";
  # ====================================================================
  # SERVICES AND HARDWARE
  # ====================================================================
  #OPENRGB STUFF
  services.hardware.openrgb.enable = true;
  hardware.i2c.enable = true;
  #STEAM STUFF
  programs.gamescope.capSysNice = true;
  programs.gamemode.enable = true;  
  hardware.steam-hardware.enable = true;
  programs.steam.enable = true;
  programs.steam.dedicatedServer.openFirewall = true;
  # ====================================================================
  # CRON
  # ====================================================================  
services.cron = {
  enable = false;
  systemCronJobs = [
		#backs up music
		"0  12 * * * ~/scripts/cron_scripts/music-backup.sh >/dev/null 2>&1"
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
		"*/30 * * * * ~/scripts/cron_scripts/wallpaper.sh  >/dev/null 2>&1"
  ];
};
  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
    environment.systemPackages = with pkgs; [
    # --- System Utilities/Shell ---
    cron
    rocmPackages.rocm-smi 
	corectrl
    # --- Btrfs Tools ---
    # --- Gaming/GPU/Emulation ---
    gamescope
    mesa
    protonup-qt 
    obs-studio
    obs-cli
    mangohud
    # --- Wayland Utilities ---
    # --- Desktop/Theming ---
    openrgb-with-all-plugins
    # --- Applications/Communication ---
    # --- Other Tools ---
  ];
}

