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
  systemd.services."getty@tty1" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin moonburst --noclear --keep-baud %I 115200,38400,9600 $TERM"
    ];
  };
  # Auto start Hyprland on Login to TTY1
  environment.loginShellInit = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec sway
    fi
  '';
}
