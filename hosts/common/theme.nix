{ pkgs, lib, inputs, config, ... }:

let
  colorScheme = {
    base00 = "1a1a1a";
    base01 = "0F0F0F";
    base02 = "1a1a1a";
    base03 = "003399";
    base04 = "4D4E93";
    base05 = "F7F700";
    base06 = "EBDBB2";
    base07 = "cccccc";
    base08 = "FF0000";
    base09 = "FE8019";
    base0A = "FABD2F";
    base0B = "545454";
    base0C = "04f100";
    base0D = "675DDB";
    base0E = "675DDB";
    base0F = "FF8019";
  };
in
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  programs.dconf.enable = true;
  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
  environment.systemPackages = [
    inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.glib
    pkgs.gsettings-desktop-schemas
  ];

  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";

    image = pkgs.runCommand "logo.png" { } ''
      ${pkgs.imagemagick}/bin/magick -size 1x1 xc:#1E1E1E $out
    '';

    homeManagerIntegration.autoImport = true;
    homeManagerIntegration.followSystem = true;

    base16Scheme = colorScheme;

    icons = {
      enable = true;
      package = lib.mkForce inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      dark = "Numix";
      light = "Numix-Light";
    };

    cursor = {
      package = pkgs.nightdiamond-cursors;
      name = "NightDiamond-Blue";
      size = 24;
    };

    fonts = {
      sizes = { applications = 14; desktop = 14; popups = 14; };
      serif = { package = pkgs.roboto; name = "Roboto Serif"; };
      sansSerif = { package = pkgs.fira-sans; name = "Fira Sans"; };
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
      emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
    };
  };

  home-manager.users.moonburst = {
    home.file.".local/share/icons/Numix".source = "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix";
    home.file.".local/share/icons/Numix-Light".source = "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix-Light";

    # Generate Theme.qml from stylix colors
    home.file.".config/quickshell/Theme.qml".text = ''
      pragma Singleton
      import QtQuick 2.0

      QtObject {
          property color base00: "#${colorScheme.base00}"
          property color base01: "#${colorScheme.base01}"
          property color base02: "#${colorScheme.base02}"
          property color base03: "#${colorScheme.base03}"
          property color base04: "#${colorScheme.base04}"
          property color base05: "#${colorScheme.base05}"
          property color base06: "#${colorScheme.base06}"
          property color base07: "#${colorScheme.base07}"
          property color base08: "#${colorScheme.base08}"
          property color base09: "#${colorScheme.base09}"
          property color base0A: "#${colorScheme.base0A}"
          property color base0B: "#${colorScheme.base0B}"
          property color base0C: "#${colorScheme.base0C}"
          property color base0D: "#${colorScheme.base0D}"
          property color base0E: "#${colorScheme.base0E}"
          property color base0F: "#${colorScheme.base0F}"
      }
    '';
  };
}
