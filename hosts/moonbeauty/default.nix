{ config, pkgs, lib, ... }:

{
  imports = [
    ../common/default.nix      # Brings in all shared logic (User, BTRFS, Audio, etc)
  #  ./packages.nix             # The GUI/Gaming list
    ./moonbeauty-hardware.nix  # Drive UUIDs
    ./mounts.nix               # BTRFS Subvolume and Mount definitions
    ./services.nix             # Moonbeauty-specific services
    ./programs/audacious.nix
    ./programs/waybar          # Waybar config
  #   ./programs/sway/sway.nix
    ../common/default.nix

    ./test.nix
  ];

home-manager.users.moonburst = {
  imports = [
    ./programs/sway/sway.nix # Move it HERE
  ];
  xdg.configFile."qt5ct/qt5ct.conf".force = true;
  xdg.configFile."qt6ct/qt6ct.conf".force = true;
home.sessionVariables = {
  XDG_CURRENT_DESKTOP = "sway";
};

programs.kitty = {
  enable = true;
  settings = {
    confirm_os_window_close = 0; # From your previous request
    "map alt+up" = "scroll_line_up";
    "map alt+down" = "scroll_line_down";
    "map alt+page_up" = "scroll_page_up";
    "map alt+page_down" = "scroll_page_down";
    "map alt+delete" = "send_text all \\x1bd";
  };};#kitty end


  };
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

  # (Polkit and Rtkit removed as they are now in common/security.nix)

  system.stateVersion = "25.11";
}
