{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
    hashedPasswordFile = "/run/secrets-for-users/moonburst_password";
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYBYv5x6Pn22dJPgjITf+yFfv/3tgyYOrAA306F5fdh MoonBurstPlays@Gmail.com" # Desktop
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSf5Y/CzAi2TfrOoQFFIDRDkdTutjZxUo3O2QzQCuEW Moon_Laptop"              # Laptop
    ];

    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "input"
      "render"
      "corectrl"
      "i2c"
      "libvirtd"
    ];

    shell = pkgs.zsh;
  };
}
