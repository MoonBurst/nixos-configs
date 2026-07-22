{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../common/default.nix # Restores shared system settings, sops defaults, etc.
    ./moonbeauty-hardware.nix
    ./mounts.nix
    ./test.nix
    ./website
   ./ffmpeg.nix
   ./corectrl.nix
   ./services.nix
#    ./vm.nix
  ];
environment.sessionVariables = {
WLR_DRM_DEVICES = "/dev/dri/card0";
};
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
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

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];
  };

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override { extraPkgs = p: [ p.libxshmfence ]; };
  };

  boot.kernel.sysctl = {
    "kernel.print_fatal_signals" = 0;
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };

  systemd.user.slices."steam-games" = {
    sliceConfig = {
      CPUAffinity = "2 3 4 5 6 7";
      MemorySwapMax = 0;
      CPUWeight = 1000;
    };
  };

  systemd.user.slices."app-steam" = {
    sliceConfig = {
      CPUAffinity = "2 3 4 5 6 7";
    };
  };

  system.stateVersion = "26.05";
}
