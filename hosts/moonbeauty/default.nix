{ config, pkgs, inputs, lib, ... }: {
  imports = [
    #./email.nix
    ../common/default.nix
    ./moonbeauty-hardware.nix
    ./mounts.nix
    ./services.nix
    ./matrix.nix
    ./test.nix
  ];

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

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 moonburst qemu-libvirtd -"
  ];

 services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
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


 boot.kernel.sysctl = {
    "kernel.print_fatal_signals" = 0;
  };
  boot.kernelParams = [ "clearcpuid=514" ];

systemd.user.slices."steam-games" = {
  sliceConfig = {
    CPUAffinity = "2 3 4 5 6 7";
    MemorySwapMax = 0; # Strictly forbids games from using zram
    CPUWeight = 1000;   # High priority for gameplay
  };
};

systemd.user.slices."app-steam" = {
  sliceConfig = {
    CPUAffinity = "2 3 4 5 6 7";
  };
};





system.stateVersion = "25.11";
}
