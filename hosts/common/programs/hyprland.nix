{ pkgs, lib, config, ... }: 

let
  autostartConfig = import ./hyprland/autostart.nix { inherit pkgs; };
  keybindsConfig = import ./hyprland/keybinds.nix { inherit pkgs; };
  outputsConfig = import ./hyprland/outputs.nix { };
  windowRulesConfig = import ./hyprland/window-rules.nix { };
in
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.etc."xdg/hypr/hyprland.conf".text = let
    colors  = config.lib.stylix.colors.withHashtag;
    base00  = colors.base00;
    base01  = colors.base01;
    base08  = colors.base08;
  in ''
    $mod = SUPER
    ${outputsConfig}
    input {
        follow_mouse = 0
        touchpad {
            natural_scroll = false
        }
    }
    device {
        name = type:pointer
        accel_profile = flat
    }
    general {
        layout = dwindle
        col.active_border = rgb(${builtins.substring 1 6 base08})
        col.inactive_border = rgb(${builtins.substring 1 6 base01})
        allow_tearing = true
    }
    dwindle {
        pseudotile = true
        preserve_split = true
    }
    group {
        col.border_active = rgb(${builtins.substring 1 6 base08})
        col.border_inactive = rgb(${builtins.substring 1 6 base01})
        groupbar {
            col.active = rgb(${builtins.substring 1 6 base00})
            col.inactive = rgb(${builtins.substring 1 6 base00})
        }
    }
    ${windowRulesConfig}
    ${keybindsConfig}
    ${autostartConfig}
    env = AQ_DRM_DEVICES,/dev/dri/card1
  '';
}
