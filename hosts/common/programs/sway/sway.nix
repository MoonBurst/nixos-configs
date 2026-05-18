{ pkgs, lib, config, ... }: {
  imports = [
    ./autostart.nix
    ./keybinds.nix
    ./outputs.nix
    ./window-rules.nix
  ];

  # Instruct Stylix to handle Sway styling templates natively
  stylix.targets.sway.enable = true;

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;

    # Fix sandbox build failure by bypassing syntax check
    checkConfig = false;

    config = rec {
      modifier = "Mod4";

      # Explicitly empty to prevent default bar generation alongside Waybar
      bars = [ ];

      input."type:pointer" = {
        accel_profile = "flat";
      };

      focus.followMouse = false;

      keybindings = lib.mkOptionDefault {
        "${modifier}+m" = "output \"AOC 24G2W1G4 0x0000E8FA\" toggle ; output \"LG Electronics LG ULTRAWIDE 0x0003CBC2\" toggle";
        "button1" = "nop";
        "button4" = "nop";
        "button5" = "nop";
        "button6" = "nop";
        "button7" = "nop";
        "${modifier}+w" = "layout tabbed";
        "${modifier}+f" = "fullscreen";
        "${modifier}+Shift+f" = "fullscreen global";
        "${modifier}+Shift+space" = "floating toggle";
        "${modifier}+Shift+minus" = "move scratchpad";
        "${modifier}+Shift+equal" = "scratchpad show";
        "--release ${modifier}+Shift+l" = "exec ${pkgs.bash}/bin/bash ../../scripts/swaylock.sh";
      };

      startup = [
      ];
    };

    # Extract system colors with native hashtags built-in
    extraConfig = let
      colors  = config.lib.stylix.colors.withHashtag;
      base00  = colors.base00;
      base01  = colors.base01;
      base05  = colors.base05;
      base08  = colors.base08;
      gray0b  = colors.base0B;
    in ''
      set $primary "HGC CR270HDM 0x00000001"

      # Fixed: Using standard hash markers instead of CSS slash-stars
      # Syntax: client.<class> <border> <background> <text> <indicator> <child_border>
      client.focused          ${base08} ${base00} ${base05} ${base08} ${base08}
      client.focused_inactive ${gray0b} ${base00} ${gray0b} ${base01} ${base01}
      client.unfocused        ${base01} ${base00} ${gray0b} ${base01} ${base01}
      client.urgent           ${base08} ${base00} ${base05} ${base08} ${base08}
    '';
  };
}
