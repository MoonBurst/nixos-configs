{ pkgs, ... }:

{
  services.dunst = {
    enable = true;

    package = pkgs.dunst.overrideAttrs (oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
      postInstall = (oldAttrs.postInstall or "") + ''
        wrapProgram $out/bin/dunst \
          --set XDG_DATA_DIRS "${pkgs.adwaita-icon-theme}/share:${pkgs.papirus-icon-theme}/share"
      '';
    });

    settings = {
      global = {
        monitor = 1;
        follow = "none";
        enable_posix_regex = true;
        width = 400;
        height = 400;
        origin = "top-right";
        offset = "15x50";
        corner_radius = 10;
        frame_width = 5;
        separator_color = "frame";
        icon_position = "left";
        min_icon_size = 92;
        max_icon_size = 92;
        icon_theme = "Papirus-Dark, Adwaita, hicolor";
        enable_recursive_icon_lookup = true;
        font = "Iosevka Term 14";
        format = "<b>%s</b>\n%b";
        show_indicators = false;
        alignment = "center";
        vertical_alignment = "center";
        browser = "${pkgs.firefox}/bin/firefox";
        always_run_script = true;
      };

      "z_luster_dawn" = {
        summary = ".*Luster Dawn.*";
        urgency = "normal";
        frame_color = "#e041de";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./luster_dawn/luster_dawn.png}";
        script = "${pkgs.writeShellScript "luster-dawn-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./luster_dawn/luster_dawn.flac}
        ''}";
      };

      "z_apogee" = {
        summary = ".*Apogee.*";
        urgency = "normal";
        frame_color = "#0CD0CD";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./apogee/apogee.png}";
        # Audio omitted: File missing
      };

      "z_solar_sonata" = {
        summary = ".*Solar Sonata.*";
        urgency = "normal";
        frame_color = "#f7f716";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./solar_sonata/solar_sonata.png}";
        script = "${pkgs.writeShellScript "solar-sonata-sound" ''
          ${pkgs.pulseaudio}/bin/paplay ${./solar_sonata/solar_sonata.flac}
        ''}";
      };

      "z_cageheart" = {
        summary = ".*Cageheart.*";
        urgency = "normal";
        frame_color = "#8ad5a6";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./cageheart/cageheart.png}";
        script = "${pkgs.writeShellScript "cageheart-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./cageheart/cageheart.flac}
        ''}";
      };

      "z_olivia" = {
        summary = ".*Olivia.*";
        urgency = "normal";
        frame_color = "#18FFD5";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./olivia/olivia.png}";
        script = "${pkgs.writeShellScript "olivia-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./olivia/olivia.flac}
        ''}";
      };

      "z_genesis_frost" = {
        summary = ".*Genesis Frost.*";
        urgency = "normal";
        frame_color = "#9ce8ff";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./genesis_frost/genesis_frost.png}";
      };
    };
  };

  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];
  environment.pathsToLink = [ "/share/icons" ];
  environment.systemPackages = with pkgs; [ librsvg iosevka libnotify ];
}
