{ pkgs, lib, config, ... }: {
  imports = [
    ./hyprland/autostart.nix
    ./hyprland/keybinds.nix
    ./hyprland/outputs.nix
  #  ./hyprland/window-rules.nix
  ];

  stylix.targets.hyprland.enable = true;

  # THIS IS THE MAGIC FIX:
  # It takes the compiled settings block below and symlinks it to where Hyprland expects it.
  xdg.configFile."hypr/hyprland.conf".source = let
    clearConfig = pkgs.writeText "hyprland.conf" config.wayland.windowManager.hyprland.extraConfig;
  in config.lib.dag.entryAfter ["writeBoundary"] clearConfig;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    settings = {
      "$mod" = "SUPER";

      # 1. FIXED: Cleanly nested the explicit_sync flag into your configuration scheme
      render = {
        explicit_sync_kms = 0;
      };

      # 2. FIXED: Injected the native environmental check bypass mechanism
      misc = {
        disable_xdg_env_checks = true;
      };

      input = {
        follow_mouse = 0;
        touchpad.natural_scroll = false;
      };

      device = [{
        name = "type:pointer";
        accel_profile = "flat";
      }];

      general.layout = "dwindle";

      bind = [
        "$mod, m, exec, hyprctl dispatch togglemonitor \"AOC 24G2W1G4 0x0000E8FA\" && hyprctl dispatch togglemonitor \"LG Electronics LG ULTRAWIDE 0x0003CBC2\""
        "$mod, w, togglefloating"
        "$mod, f, fullscreen, 0"
        "$mod SHIFT, f, fullscreen, 1"
        "$mod SHIFT, space, togglefloating"
        "$mod SHIFT, minus, movetoworkspace, special:scratchpad"
        "$mod SHIFT, equal, togglespecialworkspace, scratchpad"
      ];

      bindr = [
        "$mod SHIFT, l, exec, ${pkgs.bash}/bin/bash ../../scripts/swaylock.sh"
      ];
    };

    extraConfig = let
      colors  = config.lib.stylix.colors.withHashtag;
      base00  = colors.base00;
      base01  = colors.base01;
      base08  = colors.base08;
    in ''
      $primary = "HGC CR270HDM 0x00000001"

      general {
          col.active_border = rgb(${builtins.substring 1 6 base08})
          col.inactive_border = rgb(${builtins.substring 1 6 base01})
      }

      group {
          col.border_active = rgb(${builtins.substring 1 6 base08})
          col.border_inactive = rgb(${builtins.substring 1 6 base01})
          groupbar {
              col.active = rgb(${builtins.substring 1 6 base00})
              col.inactive = rgb(${builtins.substring 1 6 base00})
          }
      }

      # 3. FIXED: Forces proper Desktop Handshakes for external tools and apps
      env = XDG_CURRENT_DESKTOP,Hyprland
      env = XDG_SESSION_TYPE,wayland
      env = XDG_SESSION_DESKTOP,Hyprland

      # Force GPU Routing for your 7900 XT card
      env = AQ_DRM_DEVICES,/dev/dri/by-path/pci-0000:28:00.0-card
    '';
  };
}
