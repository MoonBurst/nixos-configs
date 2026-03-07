{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
    # Password managed via SOPS in security.nix
    hashedPasswordFile = "/run/secrets/sops_key";
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";

    # Permissions and hardware access
    extraGroups = [
      "networkmanager" "wheel" "audio" "video" "input"
      "render" "corectrl" "i2c" "libvirtd"
    ];

    # Default Shell
    shell = pkgs.zsh;

    # Authorized keys are managed via sops-nix in security.nix
  };
}
