{ config, pkgs, ... }:

{
  # --- Display & Desktop Services ---
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  services.dbus.enable = true;
  services.gnome.gnome-keyring.enable = true;
  services.displayManager.ly.enable = true;
  services.displayManager.sessionPackages = [pkgs.niri];


  # ====================================================================
  #PIPEWIRE AND AUDIO
  # ====================================================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 2048;
      };
    };
    extraConfig.pipewire."99-input-denoising" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "DeepFilter Noise Cancelling Source";
            "media.name" = "DeepFilter Noise Cancelling Source";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "DeepFilter Mono";
                  plugin = "${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so";
                  label = "deep_filter_mono";
                  control = {
                    "Attenuation Limit (dB)" = 100.0;
                  };
                }
              ];
            };
            "capture.props" = {
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "deep_filter_input";
              "media.class" = "Audio/Source";
            };
          };
        }
      ];
    };
  };

  systemd.user.services.pipewire.environment = {
    LADSPA_PATH = "${pkgs.deepfilternet}/lib/ladspa";
  };




  # --- System & Storage Services ---
  services.openssh.enable = true;
  services.gvfs.enable = true;
  services.journald.extraConfig = "SystemMaxUse=1G;";
  # ====================================================================
  #BTRFS AND SMART
  # ====================================================================
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    # fileSystems omitted to automatically detect all Btrfs drives in config
  };

  services.smartd = {
    enable = true;
    defaults.monitored = ''
      -a -o on -S on -n standby,q -s (S/../.././02) -M exec ${
        let
          notifyScript = pkgs.writeShellScript "smartd-notify" ''
            for bus in /run/user/*/bus; do
              if [ -S "$bus" ]; then
                UID_NUM=$(echo "$bus" | cut -d'/' -f4)
                USER_NAME=$(id -nu "$UID_NUM")
                USER_DISPLAY=$(grep -z '^DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')
                USER_WAYLAND=$(grep -z '^WAYLAND_DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')
                ${pkgs.sudo}/bin/sudo -u "$USER_NAME" \
                  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
                  DISPLAY="$USER_DISPLAY" \
                  WAYLAND_DISPLAY="$USER_WAYLAND" \
                  ${pkgs.libnotify}/bin/notify-send -u critical \
                  "SMART Disk Alert" "$SMARTD_MESSAGE"
              fi
            done
          '';
        in "${notifyScript}"
      }
    '';
  };

  # ====================================================================
  # XDG PORTALS
  # ====================================================================

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config.common = {};
  };

   # ====================================================================
   #AUTO UPGRADES
   # ====================================================================
  system.autoUpgrade = {
    enable = true;
    flake = "path:/home/moonburst/nixos-config#${config.networking.hostName}";
    flags = [ "--update-input" "nixpkgs" "-v" ];
    dates = "11:00";
    randomizedDelaySec = "30min";
    allowReboot = false;
  };

  systemd.services."notify-update-failure" = {
    description = "Capture logs and send critical desktop notification on upgrade failure";
    script = ''
      LOG_FILE="/home/moonburst/UPDATE_FAILED.txt"
      USER_NAME="moonburst"
      USER_ID=$(id -u "$USER_NAME")
      echo "--- NIXOS AUTO-UPDATE FAILED ON $(date) ---" > "$LOG_FILE"
      /run/current-system/sw/bin/journalctl -u nixos-upgrade.service -n 100 --no-pager >> "$LOG_FILE"
      chown "$USER_NAME":users "$LOG_FILE"
      if [ -S "/run/user/$USER_ID/bus" ]; then
        /run/current-system/sw/bin/systemd-run \
          --user --machine="$USER_NAME@.host" \
          /run/current-system/sw/bin/notify-send -u critical \
          "SYSTEM UPDATE FAILED" \
          "Logs saved to $LOG_FILE"
      fi
    '';
    serviceConfig.Type = "oneshot";
  };

  systemd.services.nixos-upgrade.unitConfig.OnFailure = "notify-update-failure.service";
  systemd.services.nixos-upgrade.postStop = ''
    if [ "$SERVICE_RESULT" = "success" ]; then
      rm -f /home/moonburst/UPDATE_FAILED.txt
    fi
  '';









   # ====================================================================
  # DUNST NOTIFICATIONS
  # ====================================================================
  services.dunst = {
    enable = true;
    settings = {
      # 1. GLOBAL SETTINGS (Alphabetically First)
      global = {
        monitor = 1;
        follow = "none";
        enable_posix_regex = true;
        width = "(400, 400)";
        origin = "top-right";
        offset = "(15, 50)";

        ### Appearance ###
        corner_radius = 10;
        frame_width = 5;
        separator_color = "frame";

        ### Icons ###
        icon_position = "left";
        min_icon_size = 92;
        max_icon_size = 92;
        icon_theme = "Papirus-Dark, hicolor, Adwaita";
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

      # 2. URGENCY LEVELS (Alphabetically Middle)
      urgency_low = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#007F00";
      };
      urgency_normal = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#0000FF"; # Global Blue
      };

      urgency_critical = {
        background = "#000000";
        foreground = "#f7f716";
        frame_color = "#FF0000";
        timeout = 0;
      };

      # 3. CHARACTER RULES (Alphabetically LAST via 'z_' prefix)
      "z_luster_dawn" = {
        appname = "vesktop|Electron";
        summary = ".*Luster Dawn.*";
        urgency = "normal";
        frame_color = "#e041de"; # Pink
        background = "#000000";
        foreground = "#f7f716";
        min_icon_size = 92;
        max_icon_size = 92;
        new_icon = "${./scripts/dunst/luster_dawn/luster_dawn.png}";
        script = "${pkgs.writeShellScript "luster-dawn-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./scripts/dunst/luster_dawn/luster_dawn.flac}
        ''}";
      };

      "z_solar_sonata" = {
        appname = "vesktop|Electron";
        summary = ".*Solar Sonata.*";
        urgency = "normal";
        frame_color = "#FFFF33"; # Yellow
        background = "#000000";
        foreground = "#f7f716";
        min_icon_size = 92;
        max_icon_size = 92;
        new_icon = "${./scripts/dunst/solar_sonata/solar_sonata.png}";
        script = "${pkgs.writeShellScript "solar-sonata-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./scripts/dunst/solar_sonata/solar_sonata.flac}
        ''}";
      };

      "z_apogee" = {
        appname = "vesktop|Electron";
        summary = ".*Apogee.*";
        urgency = "normal";
        frame_color = "#0CD0CD"; # Cyan
        background = "#000000";
        foreground = "#f7f716";
        min_icon_size = 92;
        max_icon_size = 92;
        new_icon = "${./scripts/dunst/apogee/apogee.png}";
      };

      "z_cageheart" = {
        appname = "vesktop|Electron";
        summary = ".*Cageheart.*";
        urgency = "normal";
        frame_color = "#8ad5a6"; # Green
        background = "#000000";
        foreground = "#f7f716";
        min_icon_size = 92;
        max_icon_size = 92;
        new_icon = "${./scripts/dunst/cageheart/cageheart.png}";
        script = "${pkgs.writeShellScript "cageheart-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./scripts/dunst/cageheart/cageheart.flac}
        ''}";
      };

      "z_olivia" = {
        appname = "vesktop";
        summary = ".*Olivia.*";
        urgency = "normal";
        frame_color = "#18FFD5"; # Light Blue
        background = "#000000";
        foreground = "#f7f716";
        min_icon_size = 92;
        max_icon_size = 92;
        new_icon = "${./scripts/dunst/olivia/olivia.png}";
        script = "${pkgs.writeShellScript "olivia-script" ''
          ${pkgs.pulseaudio}/bin/paplay ${./scripts/dunst/olivia/olivia.flac}
        ''}";
      };
    };
  };


  # Required for rendering symbolic .svg icons (Updated to current NixOS option)
  programs.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

  # Link icon folders so Dunst can see them
  environment.pathsToLink = [ "/share/icons" ];

  # Ensure these are in your systemPackages for the config above to find them
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    papirus-icon-theme
    hicolor-icon-theme
    librsvg
    iosevka
    deepfilternet
  ];
}
