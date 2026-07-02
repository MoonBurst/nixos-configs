# users nix
{ config, pkgs, lib, ... }: {
  # Main User Account
  users.users.moonburst = {
    hashedPasswordFile = "/run/secrets-for-users/moonburst_password";
    isNormalUser = true;
    group = "moonburst";
    description = "MoonBurst";
    home = "/home/moonburst";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKYBYv5x6Pn22dJPgjITf+yFfv/3tgyYOrAA306F5fdh MoonBurstPlays@Gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSf5Y/CzAi2TfrOoQFFIDRDkdTutjZxUo3O2QzQCuEW Moon_Laptop"
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

  users.groups.moonburst = {};

  # TTY Autologin
  services.getty.autologinUser = "moonburst";

  # Auto start Sway on Login to TTY1
  environment.loginShellInit = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec sway
    fi
  '';

  # Disable fallback display manager
  services.xserver.displayManager.lightdm.enable = false;

  # Force disable GNOME Keyring
  services.gnome.gnome-keyring.enable = lib.mkForce false;
}
