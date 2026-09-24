{ pkgs, lib, config, ... }: {
  imports = [
    ./autostart.nix
    ./desktop.nix
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
          command = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS XDG_CONFIG_HOME";
          always = false;
        }
        {
          command = "${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/wallpaper.sh daemon";
          always = false;
        }
        {
          command = "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock";
          always = false;
        }
        {
          command = ''
            ${pkgs.swayidle}/bin/swayidle -w \
              timeout 600 'quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock' \
              timeout 900 'swaymsg "output * power off"' \
                   resume 'swaymsg "output * power on"' \
              before-sleep 'quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock'
          '';
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
      focus_on_window_activation focus
      default_border none

      client.focused          ${base08} ${base00} ${base05} ${base08} ${base08}
      client.focused_inactive ${gray0b} ${base00} ${gray0b} ${base01} ${base01}
      client.unfocused        ${base01} ${base00} ${gray0b} ${base01} ${base01}
      client.urgent           ${base08} ${base00} ${base05} ${base08} ${base08}
    '';
  };
}
