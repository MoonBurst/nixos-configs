{ pkgs, lib, config, ... }:

let
  mkScript = name: source: pkgs.writeShellScript name (builtins.readFile source);

  gpuScript = mkScript "gpu_readout.sh" ./modules/gpu_readout.sh;
  cpuScript = mkScript "cpu_readout.sh" ./modules/cpu_readout.sh;
  ramScript = mkScript "ram_readout.sh" ./modules/ram_readout.sh;
  weatherScript = mkScript "weather_readout.sh" ./modules/weather_readout.sh;
  dunstScript = mkScript "dunst_count.sh" ./modules/dunst_count.sh;
  alarmScript = mkScript "alarm.sh" ./modules/alarm.sh;
  musicScript = mkScript "music_portal.sh" ./modules/music_portal.sh;
  borgScript = mkScript "borg_status.sh" ./modules/borg_status.sh;

  isDesktop = config.networking.hostName == "moonbeauty";

  waybarConfig = pkgs.writeText "waybar-config" (builtins.toJSON {
    layer = "top";
    position = "top";
    spacing = 2;

    modules-left = [
      "clock#day"
      "custom/weather"
      "custom/dunst_count"
      "custom/music"
      "custom/alarm"
      "custom/borg"
    ];

    modules-right = [
      "clock"
      "pulseaudio"
      "pulseaudio#microphone"
      "network"
    ]
    ++ (if isDesktop then [ "bluetooth" "custom/gpu_readout" ] else [ "battery" "backlight" ])
    ++ [
      "custom/cpu_readout"
      "custom/ram_readout"
      "tray"
    ];

    "custom/music" = {
      "format" = "   {}";
      "interval" = 2;
      "escape" = true;
      "exec" = "${pkgs.audacious}/bin/audtool current-song 2>/dev/null || echo 'Stopped'";
      "on-click" = "${pkgs.bash}/bin/bash ${musicScript} ui";
      "on-click-middle" = "${pkgs.bash}/bin/bash ${musicScript}";
      "on-click-right" = "${pkgs.bash}/bin/bash ${musicScript} add";
      "max-length" = 30;
      "tooltip" = false;
    };

    "custom/alarm" = {
      "format" = "{}";
      "return-type" = "json";
      "exec" = "${pkgs.bash}/bin/bash ${alarmScript}";
      "on-click" = "${pkgs.bash}/bin/bash ${alarmScript} set";
      "on-click-right" = "${pkgs.bash}/bin/bash ${alarmScript} cancel";
      "interval" = 1;
      "signal" = 8;
      "tooltip" = false;
    };

    "pulseaudio#microphone" = {
      "format" = "{format_source}";
      "format-source" = "";
      "format-source-muted" = " ";
      "on-click" = "${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle";
      "scroll-step" = 5; "tooltip" = false;
    };

    "custom/gpu_readout" = {
      "exec" = "${pkgs.coreutils}/bin/timeout 1s ${pkgs.bash}/bin/bash ${gpuScript} 0 | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 2; "min-length" = 30; "max-length" = 30; "tooltip" = false;
    };

    "custom/cpu_readout" = {
      "exec" = "${pkgs.coreutils}/bin/timeout 1s ${pkgs.bash}/bin/bash ${cpuScript} | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 2; "min-length" = 15; "max-length" = 15; "tooltip" = false;
    };

    "custom/ram_readout" = {
      "exec" = "${pkgs.coreutils}/bin/timeout 1s ${pkgs.bash}/bin/bash ${ramScript} | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 2;
      "return-type" = "json";
    };

    "custom/weather" = {
      "exec" = "${pkgs.coreutils}/bin/timeout 2s ${pkgs.bash}/bin/bash ${weatherScript} | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 600;
      "return-type" = "json";
      "tooltip" = true;
    };

    "custom/dunst_count" = {
      "exec" = "${pkgs.bash}/bin/bash ${dunstScript}";
      "interval" = 5;
      "on-click" = "${pkgs.dunst}/bin/dunstctl set-paused toggle";
      "tooltip" = false;
    };

    "battery" = {
      "states" = { "warning" = 30; "critical" = 15; };
      "format" = "{capacity}% {icon}";
      "format-charging" = "{capacity}% ";
      "format-plugged" = "{capacity}% ";
      "format-icons" = [ "" "" "" "" "" ];
      "tooltip" = false;
    };

    "backlight" = {
      "device" = "intel_backlight";
      "format" = "{percent}% {icon}";
      "format-icons" = ["" "" "" "" "" "" "" "" ""];
      "on-scroll-up" = "${pkgs.brightnessctl}/bin/brightnessctl set 1%+";
      "on-scroll-down" = "${pkgs.brightnessctl}/bin/brightnessctl set 1%-";
    };

    "idle_inhibitor" = {
      "format" = "{icon}";
      "format-icons" = { "activated" = ""; "deactivated" = ""; };
      "tooltip" = false;
    };

    "clock" = { "format" = "{:%I:%M:%p}"; "interval" = 5; "tooltip" = false; };
    "clock#day" = { "format" = "{:%a %d %b}"; "tooltip-format" = "<tt><small>{calendar}</small></tt>"; };

    "network" = {
      "min-length" = 25;
      "max-length" = 25;
      "format-wifi" = " {bandwidthDownBytes}  {bandwidthUpBytes} ";
      "format-ethernet" = "{bandwidthDownBytes}  | {bandwidthUpBytes} ";
      "format-linked" = "(No IP)";
      "format-disconnected" = "";
      "on-click" = "iwmenu -l custom --launcher-command \"sherlock\"";
      "tooltip" = false;
      "interval" = 1;
    };

    "pulseaudio" = {
      "format" = "{volume}% {icon}";
      "on-click" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      "format-icons" = { "default" = [ "" "" "" ]; };
      "tooltip" = false;
    };

    "bluetooth" = {
      "format" = " {status}";
      "format-disabled" = "";
      "format-off" = "";
      "interval" = 30;
      "on-click" = "${pkgs.blueman}/bin/blueman-manager";
      "tooltip" = false;
    };

    "tray" = { "icon-size" = 21; "spacing" = 1; };

"custom/borg" = {
  "format" = "{}";
  "return-type" = "json";
  "interval" = 5;
  "exec" = "${borgScript}";
  "on-click" = "${pkgs.kitty}/bin/kitty -e journalctl -u borgbackup-job-MoonBeauty-Offsite.service -f";
  "tooltip" = true;
  "escape" = true;
};


  });

  waybarStyle = let
    cfgColors = config.lib.stylix.colors.withHashtag;
    base      = cfgColors.base00; # #1a1a1a
    bubble    = cfgColors.base01; # #0F0F0F
    outline   = cfgColors.base03; # #003399
    text      = cfgColors.base05; # #F7F700
    red       = cfgColors.base08; # #FF0000
    gray0b    = cfgColors.base0B; # #545454

  in pkgs.writeText "waybar-style" ''
    /* --- Dynamic Anti-Burn-In Keyframes --- */
    @keyframes antiBurnOutline {
      0%   { border-color: ${outline}; }
      50%  { border-color: ${gray0b}; } /* Cycles subtly to base0B gray */
      100% { border-color: ${outline}; }
    }

    @keyframes antiBurnBase {
      0%   { background-color: ${base}; }
      50%  { background-color: ${bubble}; }
      100% { background-color: ${base}; }
    }

    @keyframes antiBurnBubble {
      0%   { background-color: ${bubble}; border-color: ${outline}; }
      50%  { background-color: ${base}; border-color: ${gray0b}; }
      100% { background-color: ${bubble}; border-color: ${outline}; }
    }

    /* --- Waybar Geometry Config --- */
    * {
      font-family: JetBrainsMono Nerd Font, FontAwesome, Roboto, sans-serif;
      font-size: 15px;
      border-radius: 0.75em;
    }

    window#waybar {
      border: 2px solid ${outline};
      background: ${base};
      box-shadow: 1px 1px 10px 10px ${base};
      color: ${text};
      transition-property: background-color;
      transition-duration: 0.5s;
      animation: antiBurnBase 60s ease-in-out infinite, antiBurnOutline 90s ease-in-out infinite;
    }

    window#waybar.hidden {
      opacity: 0.2;
    }

    tooltip {
      background: ${base};
      border: 1px solid ${gray0b};
    }

    tooltip label {
      color: ${text};
    }

    label:focus {
      background-color: #000000;
    }

    button {
      box-shadow: inset 0 -3px transparent;
      border: none;
      border-radius: 0;
    }

    box {
      border: none;
    }

    #workspaces label {
      font-size: 15px;
    }

    #workspaces button {
      padding: 0 0.5em;
      background-color: ${bubble};
      color: ${text};
      margin: 0.25em;
      animation: antiBurnBubble 80s ease-in-out infinite;
    }

    #workspaces button.active {
      color: ${gray0b};
    }

    #workspaces button.urgent {
      background-color: ${red};
      color: ${text};
      animation: none;
    }

    /* --- Module Selectors Mapping --- */
    .niri-taskbar, #backlight, #battery, #bluetooth, #clock, #cpu, #custom-beats,
    #custom-borg, #custom-3dprinter, #custom-cpu_readout, #custom-dunst_count,
    #custom-github, #custom-gpu_readout, #custom-music, #custom-notification,
    #custom-pipewire, #custom-pipewire.muted, #custom-ram_readout,
    #custom-separator-left, #custom-separator-right, #custom-pacman_updates,
    #custom-vram_readout, #custom-wayves, #custom-weather, #custom-alarm, #disk,
    #idle_inhibitor, #keyboard-state, #memory, #mpd, #network, #notifications,
    #pulseaudio, #pulseaudio.muted, #taskbar, #temperature, #tray, #user,
    #window, #wireplumber, #workspaces {
      padding: 0 0.5em;
      margin: 0.005em;
      padding-left: 10px;
      padding-right: 10px;
      font-weight: bold;
      background-color: ${bubble};
      border: 2px solid ${outline};
      animation: antiBurnBubble 75s ease-in-out infinite;
    }

    #custom-updates.updated {
      padding-left: 0;
      padding-right: 1em;
    }

    #custom-updates {
      color: ${red};
    }

    #user {
      color: ${gray0b};
    }

    #network.disconnected {
      background-color: ${red};
      animation: none;
    }

    #temperature.critical {
      background-color: ${red};
      animation: none;
    }

    #keyboard-state > label {
      padding: 0 5px;
    }

    #keyboard-state > label.locked {
      background: rgba(0, 0, 0, 0.2);
    }

    #custom-wlogout {
      font-size: 1.75em;
      padding-right: 0.5em;
      padding-left: 0.5em;
      color: ${gray0b};
    }

    @keyframes blink {
      to {
        background-color: ${text};
        color: ${base};
      }
    }
  '';

in {
  systemd.user.services.waybar = {
    description = "Waybar status bar";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    path = with pkgs; [
      bash coreutils procps gawk gnugrep gnused bc jq curl lm_sensors
      rocmPackages.rocm-smi playerctl pulseaudio dunst libnotify
      wireplumber findutils yad audacious sox systemd util-linux
      brightnessctl rclone
    ];

    serviceConfig = {
      ExecStart = "${pkgs.waybar}/bin/waybar -c ${waybarConfig} -s ${waybarStyle}";
      Restart = "always";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP XDG_SESSION_TYPE";
    };
  };
}
