{ config, pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "us"; variant = ""; };
  services.dbus.enable = true;
  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.sway = {
      default = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };
}
