{ pkgs, config, lib, ... }: {
  # Registers the quickshell PAM service and enables GNOME Keyring unlocking.
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

  systemd.user.services.quickshell = {
    description = "Quickshell Desktop Shell";
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    # Prevents Quickshell from restarting on Nix switches
    unitConfig = {
      X-SwitchToConfiguration-Trigger-By = "";
    };

    # Native NixOS/Home Manager environment attribute set for colors
    environment = let
      validColors = lib.filterAttrs (name: value:
        (lib.hasPrefix "base" name) && (builtins.isString value)
      ) config.lib.stylix.colors.withHashtag;

      # Maps base00-base0F colors to STYLIX_BASE00 and automatically translates hyphens to underscores
      colorEnv = lib.mapAttrs' (name: value:
        lib.nameValuePair (builtins.replaceStrings ["-"] ["_"] "STYLIX_${lib.toUpper name}") value
      ) validColors;
    in colorEnv // {
      NIXOS_SWAYMSG_PATH = "${pkgs.sway}/bin/swaymsg";
      NIXOS_DBUSSEND_PATH = "${pkgs.dbus}/bin/dbus-send";
    };

    serviceConfig = {
      # Cleaned wrapper; variables are now inherited properly from systemd
      ExecStart = "${pkgs.bash}/bin/bash -c 'export PATH=/run/wrappers/bin:/home/moonburst/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin; exec ${pkgs.quickshell}/bin/quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml'";
      Restart = "always";
      RestartSec = "2";
    };

    # Note: wantedBy is removed to prevent the race condition at boot.
  };
}
