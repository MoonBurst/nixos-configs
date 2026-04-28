{ pkgs, lib, config, ... }:

let
  resourcePath = ./resources;

  characters = [
    { name = "apogee";        summary = "Apogee";        color = "#0CD0CD"; }
    { name = "solar_sonata";  summary = "Solar Sonata";  color = "#f7f716"; sound = true; }
    { name = "cageheart";     summary = "Cageheart";     color = "#8ad5a6"; sound = true; }
    { name = "olivia";        summary = "Olivia";        color = "#18FFD5"; sound = true; }
    { name = "genesis_frost"; summary = "Genesis Frost"; color = "#9ce8ff"; }
    { name = "luster_dawn";   summary = "Luster Dawn";   color = "#e041de"; sound = true; }
  ];

  makeRule = { name, summary, color, sound ? false }: ''
    [z_${name}]
    summary = ".*${summary}.*"
    frame_color = "${color}"
    new_icon = "${resourcePath}/${name}/${name}.png"
    ${if sound
      then "script = \"${pkgs.writeShellScript "${name}-sound" "${pkgs.pulseaudio}/bin/paplay ${resourcePath}/${name}/${name}.flac"}\""
      else ""}
  '';

  dunstrc_content = ''
    [global]
    monitor = 1
    follow = none
    enable_posix_regex = true
    width = 400
    height = (0, 400)
    origin = top-right
    offset = (15, 50)
    corner_radius = 10
    frame_width = 5
    separator_color = frame
    icon_position = left
    min_icon_size = 100
    max_icon_size = 100

    # Set Papirus as the primary theme for lookup
    icon_theme = "Papirus-Dark, Adwaita, hicolor"
    enable_recursive_icon_lookup = true

    # Updated paths for Papirus on NixOS
    icon_path = "/run/current-system/sw/share/icons/Papirus-Dark/48x48/status:/run/current-system/sw/share/icons/Papirus-Dark/48x48/devices:/run/current-system/sw/share/icons/Papirus-Dark/48x48/apps:/run/current-system/sw/share/icons/hicolor/48x48/apps"

    default_icon = "${resourcePath}/fallback.png"

    font = "Iosevka Term 14"
    format = "<b>%s</b>\n%b"
    markup = strip
    always_run_script = true

    [urgency_low]
    background = "#000000"
    foreground = "#f7f716"
    frame_color = "#007F00"
    timeout = 5

    [urgency_normal]
    background = "#000000"
    foreground = "#f7f716"
    frame_color = "#0000FF"
    timeout = 5

    ${lib.concatStringsSep "\n" (map makeRule characters)}
  '';

  dunstConfig = pkgs.writeText "dunstrc" dunstrc_content;
in
{
  home-manager.users.moonburst = {
    services.mako.enable = lib.mkForce false;

    services.dunst = {
      enable = true;
      configFile = dunstConfig;
      package = pkgs.dunst.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
        postInstall = (oldAttrs.postInstall or "") + ''
          wrapProgram $out/bin/dunst \
            --set XDG_DATA_DIRS "${pkgs.adwaita-icon-theme}/share:${pkgs.papirus-icon-theme}/share" \
            --prefix GDK_PIXBUF_MODULE_FILE : "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
        '';
      });
    };
  };

  # Make sure the icon theme is actually in your system profile
  environment.systemPackages = [
    pkgs.libnotify
    pkgs.pulseaudio
    pkgs.file
    pkgs.librsvg
    pkgs.papirus-icon-theme
    pkgs.adwaita-icon-theme
  ];
  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
}
