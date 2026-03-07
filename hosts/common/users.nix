{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
  hashedPasswordFile = "/run/secrets-for-users/moonburst_password";
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";

    extraGroups = [
      "networkmanager" "wheel" "audio" "video" "input"
      "render" "corectrl" "i2c" "libvirtd"
    ];

    shell = pkgs.zsh;

  };
}
