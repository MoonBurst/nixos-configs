{ pkgs, lib, config, ... }:

{
  imports = [
    ./autostart.nix
    ./keybinds.nix
    ./outputs.nix
    ./window-rules.nix
  ];

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;

    config = rec {
      modifier = "Mod4";
      left = "h";
      down = "j";
      up = "k";
      right = "l";

      # THIS LINE KILLS THE DEFAULT SWAYBAR
      bars = [ ];

      input."type:pointer" = {
        accel_profile = "flat";
      };

      focus.followMouse = false;

      keybindings = lib.mkOptionDefault {
        "${modifier}+m" = "output \"AOC 24G2W1G4 0x0000E8FA\" toggle ; output \"LG Electronics LG ULTRAWIDE 0x0003CBC2\" toggle";
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
        "--release ${modifier}+Shift+l" = "exec ${pkgs.bash}/bin/bash ~/nixos-config/hosts/moonbeauty/scripts/swaylock.sh";
      };

      startup = [
        # If you use Waybar, add it here:
        # { command = "${pkgs.waybar}/bin/waybar"; }
      ];
    };

    extraConfig = ''
      set $primary "HGC CR270HDM 0x00000001"
      client.focused          "#de0b0b" "#000000" "#f2ea07" "#de0b0b" "#de0b0b"
      client.focused_inactive "#999999" "#000000" "#666666" "#999999" "#999999"
      client.unfocused        "#999999" "#000000" "#666666" "#999999" "#999999"
    '';
  };
}
