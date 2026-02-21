{ config, pkgs, lib, ... }:

{
  imports = [
   ./audio.nix         # Pipewire and EasyEffects stack
   ./btrfs.nix         # BTRFS auto-scrubbing and maintenance logic
   ./dunst/dunst.nix        # Custom Dunst notification theme and rules
   ./obs.nix
   ./packages.nix      # CLI tools, Desktop Apps, and Fonts
   ./security.nix      # SOPS secrets, GPG, and Polkit
   ./services.nix      # System daemons, Portal logic, and Auto-upgrades
   ./theme.nix
   ./users.nix         # User account (moonburst) and permissions
   ./zsh.nix           # Shell configuration and aliases
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
