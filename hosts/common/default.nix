{ config, pkgs, lib, ... }:

{
  imports = [
    ./packages.nix      # CLI tools, Desktop Apps, and Fonts
    ./services.nix      # System daemons, Portal logic, and Auto-upgrades
    ./zsh.nix           # Shell configuration and aliases
    ./security.nix      # SOPS secrets, GPG, and Polkit
    ./users.nix         # User account (moonburst) and permissions
    ./audio.nix         # Pipewire and EasyEffects stack
   ./dunst/dunst.nix        # Custom Dunst notification theme and rules
    ./btrfs.nix         # BTRFS auto-scrubbing and maintenance logic
  ];

  # --- Localization ---
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Nix Settings ---
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = lib.mkDefault "auto";
    auto-optimise-store = true;
  };

  # --- System Housekeeping ---
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
}
