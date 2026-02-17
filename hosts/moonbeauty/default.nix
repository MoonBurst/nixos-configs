{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/default.nix      # Brings in all the stuff above
    ./packages.nix             # The GUI/Gaming list we made
    ./moonbeauty-hardware.nix
    ./mounts.nix
    ./services.nix
    ./programs/waybar
    ./test.nix
  ];

  networking.hostName = "moonbeauty";

  # --- Hardware & RGB ---
  services.hardware.openrgb.enable = true;
  hardware.i2c.enable = true;

  # --- Gaming ---
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
  };
  programs.gamemode.enable = true;
  programs.gamescope.capSysNice = true;
  hardware.steam-hardware.enable = true;

  # --- Virtualization (VMs) ---
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 moonburst qemu-libvirtd -"
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="moonburst", GROUP="kvm", MODE="0660"
  '';

  # --- System Compatibility ---
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override { extraPkgs = p: [ p.libxshmfence ]; };
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;

  system.stateVersion = "25.11";
}
