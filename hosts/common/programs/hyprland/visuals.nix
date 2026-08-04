{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      layout = "dwindle";
      resize_on_border = true;
    };

    decoration = {
      rounding = 10;
      active_opacity = 1.0;
      inactive_opacity = 0.9;

      blur = {
        enabled = true;
        size = 4;
        passes = 2;
        new_optimizations = true;
      };
    };

    animations = {
      enabled = true;
      bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
      animation = [
        "windows, 1, 5, myBezier"
        "windowsOut, 1, 5, default, popin 80%"
        "border, 1, 8, default"
        "fade, 1, 5, default"
        "workspaces, 1, 5, default"
      ];
    };
  };
}
