{ pkgs, config, lib, ... }: {
  security.pam.services.quickshell = {
    text = ''
      auth      include   login
      auth      optional  pam_gnome_keyring.so

      account   include   login

      session   include   login
      session   optional  pam_gnome_keyring.so auto_start

      password  include   login
    '';
  };

  # New systemd user service for Horizon Electron
  systemd.user.services.horizon = {
    description = "Horizon Electron Client";
    serviceConfig = {
      # Uses the absolute path you located
      ExecStart = "/etc/profiles/per-user/moonburst/bin/horizon-electron --password-store=gnome-libsecret";
      Restart = "no";
    };
  };

  systemd.user.services.quickshell = {
    description = "Quickshell Desktop Shell";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    unitConfig = {
      X-SwitchToConfiguration-Trigger-By = "";
    };

    environment = let
      validColors = lib.filterAttrs (name: value:
        (lib.hasPrefix "base" name) && (builtins.isString value)
      ) config.lib.stylix.colors.withHashtag;

      colorEnv = lib.mapAttrs' (name: value:
        lib.nameValuePair (builtins.replaceStrings ["-"] ["_"] "STYLIX_${lib.toUpper name}") value
      ) validColors;
    in colorEnv // {
      NIXOS_SWAYMSG_PATH = "${pkgs.sway}/bin/swaymsg";
      NIXOS_DBUSSEND_PATH = "${pkgs.dbus}/bin/dbus-send";
    };

    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c 'export PATH=/run/wrappers/bin:/home/moonburst/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin; exec ${pkgs.quickshell}/bin/quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml'";
      Restart = "always";
      RestartSec = "2";
    };
  };
}
