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
    systemd.enable = true; # Automatically starts graphical-session.target (which triggers Quickshell)

    checkConfig = false;

    config = rec {
      modifier = "Mod4";

      bars = [ ];

      input."type:pointer" = {
        accel_profile = "flat";
      };

      focus.followMouse = false;

      # Compact, clean startup scripts
      startup = [
        {
          # Update the activation environment for Systemd/DBus on Wayland startup
          command = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_DATA_DIRS XDG_CONFIG_HOME";
          always = false;
        }
        {
          # Start the wallpaper script daemon
          command = "${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/wallpaper.sh daemon";
          always = false;
        }
        {
          # Locks the screen exactly once when you first log in to Sway, never on reloads
          command = "quickshell ipc lockscreen lock";
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
