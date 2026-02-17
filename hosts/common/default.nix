{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./packages.nix      # The CLI/Font list we just made
    ./services.nix
    ./zsh.nix
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Localization ---
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Nix Settings ---
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = lib.mkDefault "auto";
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # --- Core Networking & Hardware ---
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # --- User Account ---
  users.users.moonburst = {
    hashedPasswordFile = config.sops.secrets.sops_key.path;
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";
    extraGroups = [
      "networkmanager" "wheel" "audio" "video"
      "input" "render" "corectrl" "i2c" "libvirtd"
    ];
    shell = pkgs.zsh;
  };

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
    secrets.sops_key.neededForUsers = true;
  };

  # --- Shared Programs ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.fuse.userAllowOther = true;
}
