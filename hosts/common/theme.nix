{ pkgs, lib, inputs, ... }:

{
  # 1. Essential for SVG icons and settings persistence
  programs.dconf.enable = true;
  services.xserver.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  environment.systemPackages = [
    inputs.moon-numix.packages.${pkgs.system}.default
    pkgs.glib # provides gsettings
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

    targets.qt.enable = true;
    targets.qt.platform = "qtct";
    targets.gtk.enable = true;

    icons = {
      enable = true;
      package = lib.mkForce inputs.moon-numix.packages.${pkgs.system}.default;
      dark = lib.mkForce "Numix";
      light = lib.mkForce "Numix-Light";
    };

    cursor = {
      package = pkgs.nightdiamond-cursors;
      name = "NightDiamond-Blue";
      size = 24;
    };

    base16Scheme = {
      base00 = "1E1E1E"; base01 = "0F0F0F"; base02 = "544E5A"; base03 = "003399";
      base04 = "4D4E93"; base05 = "CECB00"; base06 = "EBDBB2"; base07 = "FBF1C7";
      base08 = "FF0000"; base09 = "FE8019"; base0A = "FABD2F"; base0B = "B8BB26";
      base0C = "8EC07C"; base0D = "675DDB"; base0E = "675DDB"; base0F = "FF8019";
    };

    fonts = {
      sizes = { applications = 14; desktop = 14; popups = 14; };
      serif = { package = pkgs.roboto; name = "Roboto Serif"; };
      sansSerif = { package = pkgs.fira-sans; name = "Fira Sans"; };
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
      emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
    };
  };
}
