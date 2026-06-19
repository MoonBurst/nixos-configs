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
          command = (
            let
              colors = config.lib.stylix.colors.withHashtag;
              wallpaperScript = "/home/moonburst/nix/hosts/common/scripts/wallpaper.sh";
            in
              "exec ${pkgs.bash}/bin/bash -c \"${pkgs.toybox}/bin/killall -q quickshell || true && ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS XDG_CONFIG_HOME && ${pkgs.bash}/bin/bash ${wallpaperScript} daemon & STYLIX_BASE00='${colors.base00}' STYLIX_BASE01='${colors.base01}' STYLIX_BASE03='${colors.base03}' STYLIX_BASE05='${colors.base05}' STYLIX_BASE08='${colors.base08}' NIXOS_SWAYMSG_PATH='${pkgs.sway}/bin/swaymsg' NIXOS_DBUSSEND_PATH='${pkgs.dbus}/bin/dbus-send' quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml\""
          );
          always = true;
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
      default_border none

      # Syntax: client.<class> <border> <background> <text> <indicator> <child_border>
      client.focused          ${base08} ${base00} ${base05} ${base08} ${base08}
      client.focused_inactive ${gray0b} ${base00} ${gray0b} ${base01} ${base01}
      client.unfocused        ${base01} ${base00} ${gray0b} ${base01} ${base01}
      client.urgent           ${base08} ${base00} ${base05} ${base08} ${base08}
    '';
  };
}
