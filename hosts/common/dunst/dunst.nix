{ pkgs, ... }:

let
  dunstCustom = pkgs.dunst.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/dunst \
        --set XDG_DATA_DIRS "${pkgs.adwaita-icon-theme}/share:${pkgs.papirus-icon-theme}/share"
    '';
  });

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
    
    ### ICON SIZE FIX ###
    icon_position = left
    min_icon_size = 92
    max_icon_size = 128
    icon_theme = "Papirus-Dark, Adwaita, hicolor"
    enable_recursive_icon_lookup = true
    
    font = "Iosevka Term 14"
    format = "<b>%s</b>\n%b"
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

    ### CHARACTER RULES (BOTTOM = HIGHEST PRIORITY) ###

    [z_apogee]
    summary = ".*Apogee.*"
    frame_color = "#0CD0CD"
    new_icon = "${./apogee/apogee.png}"

    [z_solar_sonata]
    summary = ".*Solar Sonata.*"
    frame_color = "#f7f716"
    new_icon = "${./solar_sonata/solar_sonata.png}"
    script = "${pkgs.writeShellScript "solar-sonata-sound" "export PATH=$PATH:${pkgs.pulseaudio}/bin; paplay ${./solar_sonata/solar_sonata.flac}"}"

    [z_cageheart]
    summary = ".*Cageheart.*"
    frame_color = "#8ad5a6"
    new_icon = "${./cageheart/cageheart.png}"
    script = "${pkgs.writeShellScript "cageheart-script" "export PATH=$PATH:${pkgs.pulseaudio}/bin; paplay ${./cageheart/cageheart.flac}"}"

    [z_olivia]
    summary = ".*Olivia.*"
    frame_color = "#18FFD5"
    new_icon = "${./olivia/olivia.png}"
    script = "${pkgs.writeShellScript "olivia-script" "export PATH=$PATH:${pkgs.pulseaudio}/bin; paplay ${./olivia/olivia.flac}"}"

    [z_genesis_frost]
    summary = ".*Genesis Frost.*"
    frame_color = "#9ce8ff"
    new_icon = "${./genesis_frost/genesis_frost.png}"

    [z_luster_dawn]
    summary = ".*Luster Dawn.*"
    frame_color = "#e041de"
    new_icon = "${./luster_dawn/luster_dawn.png}"
    script = "${pkgs.writeShellScript "luster-dawn-script" "export PATH=$PATH:${pkgs.pulseaudio}/bin; paplay ${./luster_dawn/luster_dawn.flac}"}"
  '';

  dunstConfig = pkgs.writeText "dunstrc" dunstrc_content;
in
{
  environment.systemPackages = [ dunstCustom pkgs.libnotify pkgs.pulseaudio ];
  services.dbus.packages = [ dunstCustom ];

  systemd.user.services.dunst = {
    description = "Dunst notification daemon";
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${dunstCustom}/bin/dunst -config ${dunstConfig}";
      Restart = "always";
    };
    wantedBy = [ "graphical-session.target" ];
  };

  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
}
