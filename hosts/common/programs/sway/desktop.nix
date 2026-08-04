{ pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-wlr
    ];
    config = {
      sway = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
        "org.freedesktop.impl.portal.Inhibit" = [ "none" ];
      };
    };
  };

  # Generate portal screencast configuration
  xdg.configFile."xdg-desktop-portal-wlr/config".text = ''
    [screencast]
    chooser_type=dmenu
    chooser_cmd=${pkgs.gnugrep}/bin/grep 'DP-1'
  '';

  # High-priority drop-in override to guarantee %h/.config is loaded
  xdg.configFile."systemd/user/xdg-desktop-portal-wlr.service.d/z-override.conf".text = ''
    [Service]
    ExecStart=
    ExecStart=${pkgs.xdg-desktop-portal-wlr}/libexec/xdg-desktop-portal-wlr --config=%h/.config/xdg-desktop-portal-wlr/config
  '';
}
