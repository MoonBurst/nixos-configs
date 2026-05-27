{ pkgs, lib, config, ... }: {
  imports = [
    ./autostart.nix
    ./keybinds.nix
    ./outputs.nix
    ./window-rules.nix
  ];

  stylix.targets.sway.enable = true;

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;

    checkConfig = false;

    config = rec {
      modifier = "Mod4";

      bars = [ ];

      input."type:pointer" = {
        accel_profile = "flat";
      };

      focus.followMouse = false;

      startup = [
        {
          command = ''
            ${pkgs.toybox}/bin/killall -q quickshell || true; \
            NIXOS_SWAYMSG_PATH='${pkgs.sway}/bin/swaymsg' \
            NIXOS_DBUSSEND_PATH='${pkgs.dbus}/bin/dbus-send' \
            quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml
          '';
          always = true;
        }

        {
          command = "quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock";
          always = false;
        }
      ];
    };

    extraConfig = let
      colors  = config.lib.stylix.colors.withHashtag;
      base00  = colors.base00;
      base01  = colors.base01;
      base05  = colors.base05;
      base08  = colors.base08;
      gray0b  = colors.base0B;
    in ''
      set $primary "HGC CR270HDM 0x00000001"
      no_focus [window_role="pop-up"]
      # Forces apps to focus smoothly when requested by deep-linking widgets
      focus_on_window_activation focus

      # Syntax: client.<class> <border> <background> <text> <indicator> <child_border>
      client.focused          ${base08} ${base00} ${base05} ${base08} ${base08}
      client.focused_inactive ${gray0b} ${base00} ${gray0b} ${base01} ${base01}
      client.unfocused        ${base01} ${base00} ${gray0b} ${base01} ${base01}
      client.urgent           ${base08} ${base00} ${base05} ${base08} ${base08}
    '';
  };
}
