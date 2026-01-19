# moonbeauty - Desktop Host Configuration
{
  config,
  pkgs,
  lib,
  niri-flake,
  cypkgs,
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
    openrgb-with-all-plugins
    # --- Gaming/GPU/Emulation ---
    gamescope#for steam
    mesa#GPU driverrs
    protonup-qt#for steam
    obs-studio#obs
    obs-cli#obs
    mangohud#system use/FPS counter
    # --- Desktop/Theming ---
    lmstudio#AI LLM
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
    ];

  system.stateVersion = "25.11";
}
