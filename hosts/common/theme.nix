{ pkgs, lib, inputs, config, ... }:

let
  colorScheme = {
    base00 = "#1a1a1a";
    base01 = "#0F0F0F";
    base02 = "#1a1a1a";
    base03 = "#003399";
    base04 = "#4D4E93";
    base05 = "#F7F700";
    base06 = "#EBDBB2";
    base07 = "#cccccc";
    base08 = "#FF0000";
    base09 = "#FE8019";
    base0A = "#FABD2F";
    base0B = "#545454";
    base0C = "#04f100";
    base0D = "#675DDB";
    base0E = "#675DDB";
    base0F = "#FF8019";
  };
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  programs.dconf.enable = true;
  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  environment.systemPackages = [
    inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.glib
    pkgs.gsettings-desktop-schemas
    pkgs.quickshell
  ];

  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    image = pkgs.runCommand "logo.png" { } "${pkgs.imagemagick}/bin/magick -size 1x1 xc:#1E1E1E $out";
    homeManagerIntegration = { autoImport = true; followSystem = true; };
    base16Scheme = colorScheme;

    icons = {
      enable = true;
      package = lib.mkForce inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default;
      dark = "Numix"; light = "Numix-Light";
    };

    cursor = { package = pkgs.nightdiamond-cursors; name = "NightDiamond-Blue"; size = 24; };

    fonts = {
      sizes = { applications = 20; desktop = 20; popups = 20; };
      serif = { package = pkgs.roboto; name = "Roboto Serif"; };
      sansSerif = { package = pkgs.fira-sans; name = "Fira Sans"; };
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
      emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
    };
  };

  home-manager.users.moonburst = {
    home.file.".local/share/icons/Numix".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix";
    home.file.".local/share/icons/Numix-Light".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix-Light";

    home.file."nix/hosts/common/programs/quickshell/Theme.qml".text = ''
      import QtQuick 2.0

      QtObject {
          id: theme

          // ============================================================================
          // AUTOMATED STYLIX PALETTE INTERPOLATION (ONE PER LINE)
          // ============================================================================
          ${lib.concatStringsSep "\n          " (lib.mapAttrsToList (name: value: "property color ${name}: \"${value}\"") colorScheme)}

          // ============================================================================
          // CONFIGURATION PROFILES
          // ============================================================================
          property int globalFontSize: ${toString config.stylix.fonts.sizes.popups}
          property int globalHeaderSize: ${toString config.stylix.fonts.sizes.popups}
          property string fontFamily: "${config.stylix.fonts.sansSerif.name}"

          property int defaultCardWidth: 420
          property int defaultCardHeight: 140
          property int defaultCardRadius: 10
          property int globalBorderWidth: 3
          property int globalPadding: 20

          // CUSTOM BORDER COLOR SLOTS MAP TO LAUNCHER PANELS
          property color outerBorderColor: base03
          property color innerBorderColor: base05

          function getGlobalTextColor(notification) { return base05 }
      }
    '';

  };
}
