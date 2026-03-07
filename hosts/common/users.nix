{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
    # FIXED: Pointed to the new master_password path from SOPS
    hashedPasswordFile = config.sops.secrets.master_password.path;

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
