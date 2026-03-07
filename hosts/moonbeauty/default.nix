{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/default.nix      # Pulls in Sway, Waybar, Brave, and Audacious
    ./moonbeauty-hardware.nix
    ./mounts.nix
    ./services.nix
    ./matrix.nix
    ./test.nix
  ];

  networking.hostName = "moonbeauty";

  services.hardware.openrgb.enable = true;
  hardware.i2c.enable = true;

  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
  };
  programs.gamemode.enable = true;
  programs.gamescope.capSysNice = true;
  hardware.steam-hardware.enable = true;

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 moonburst qemu-libvirtd -"
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="moonburst", GROUP="kvm", MODE="0660"
  '';

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override { extraPkgs = p: [ p.libxshmfence ]; };
  };

  system.stateVersion = "25.11";
}
