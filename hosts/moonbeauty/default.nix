# moonbeauty - Desktop Host Configuration
{ config, pkgs, lib, ... }:

{
  # ====================================================================
  # MODULE IMPORTS
  # ====================================================================
  imports = [
    ../common/default.nix
    ./moonbeauty-hardware.nix
    ./mounts.nix
    ./services.nix
    ./programs/waybar
     ./test.nix
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
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  environment.systemPackages = with pkgs; [
    # --- Custom Flake Packages (from overlay in flake.nix) ---

    # --- System Utilities/Shell ---
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
