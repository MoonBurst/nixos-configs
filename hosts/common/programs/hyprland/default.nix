{ pkgs, lib, config, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  unstablePkgs = inputs.nixpkgs-unstable.legacyPackages.${system};

  hyprlandPkg = unstablePkgs.hyprland;
  hy3Pkg = unstablePkgs.hyprlandPlugins.hy3;
in
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    package = hyprlandPkg;
  };

  home-manager.users.moonburst = {
    imports = [
      ./outputs.nix
      ./autostart.nix
      ./keybinds.nix
      ./window-rules.nix
      ./hyprland-services.nix
    ];
    stylix.targets.hyprland.enable = true;

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      package = hyprlandPkg;

      plugins = [ hy3Pkg ];

      systemd.variables = [ "--all" ];

      extraConfig = ''
        hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
        hl.env("XDG_SESSION_DESKTOP", "Hyprland")
        hl.env("QT_QPA_PLATFORM", "wayland")
        hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

        hl.config({
          general = {
            gaps_in = 5,
            gaps_out = 10,
            border_size = 0,
            resize_on_border = true,
            allow_tearing = true,
            layout = "hy3"
          },
          misc = {
            disable_hyprland_logo = true,
            focus_on_activate = true
          },
          input = {
            accel_profile = "flat",
            follow_mouse = 0
          }
        })
      '';
    };
  };
}
