{ pkgs, ... }:

{
  services.dunst = {
    enable = true;

    # Wrapper to ensure Dunst finds the right icon themes in the Nix store
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

        # Fixed syntax for NixOS Dunst module
        width = 400;
        height = 400;
        origin = "top-right";
        offset = "15x50";

        ### Appearance ###
        corner_radius = 10;
        frame_width = 5;
        separator_color = "frame";

        ### Icons ###
        icon_position = "left";
        min_icon_size = 92;
        max_icon_size = 92;
        icon_theme = "Papirus-Dark, Adwaita, hicolor";
        enable_recursive_icon_lookup = true;

        ### Text ###
        font = "Iosevka Term 14";
        format = "<b>%s</b>\n%b";
        show_indicators = false;
        alignment = "center";
        vertical_alignment = "center";

        browser = "${pkgs.firefox}/bin/firefox";
        always_run_script = true;
      };

      urgency_low = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#007F00";
      };

      urgency_normal = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#0000FF";
      };

      urgency_critical = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#FF0000";
        timeout = 0;
      };

      # --- Rules using relative paths based on your Tree output ---

      "z_luster_dawn" = {
        appname = "vesktop|Electron";
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

      "z_solar_sonata" = {
        appname = "vesktop|Electron";
        summary = ".*Solar Sonata.*";
        urgency = "normal";
        frame_color = "#FFFF33";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./solar_sonata/solar_sonata.png}";
        script = "${pkgs.writeShellScript "solar-sonata-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./solar_sonata/solar_sonata.flac}
        ''}";
      };

      "z_apogee" = {
        appname = "vesktop|Electron";
        summary = ".*Apogee.*";
        urgency = "normal";
        frame_color = "#0CD0CD";
        background = "#000000";
        foreground = "#f7f716";
        new_icon = "${./apogee/apogee.png}";
      };

      "z_cageheart" = {
        appname = "vesktop|Electron";
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
        appname = "vesktop";
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
    };
  };

  # Required for rendering symbolic .svg icons
  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  # Link icon folders so Dunst can see them
  environment.pathsToLink = [ "/share/icons" ];

  environment.systemPackages = with pkgs; [
    librsvg
    iosevka
    papirus-icon-theme
    adwaita-icon-theme
  ];
}
