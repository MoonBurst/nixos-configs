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
    ];

    modules-right = [
      "clock"
      "pulseaudio"
      "pulseaudio#microphone"
      "network"
    ]
    # Logic: Desktop gets Bluetooth/GPU. Laptop (lunarchild) gets Battery/Backlight.
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
  # Note: Head -n 1 is still safe here to ensure a single JSON object
  "exec" = "${pkgs.coreutils}/bin/timeout 1s ${pkgs.bash}/bin/bash ${ramScript} | ${pkgs.coreutils}/bin/head -n 1";
  "interval" = 2;
  "return-type" = "json"; # Tells waybar to look for the 'tooltip' key in the output
};


    "custom/weather" = {
      # The head -n 1 ensures only the final JSON object is read if there is stray output
      "exec" = "${pkgs.coreutils}/bin/timeout 2s ${pkgs.bash}/bin/bash ${weatherScript} | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 600;
      "return-type" = "json"; # Critical: Tells Waybar to expect a JSON object
      "tooltip" = true;       # Enables the hover-over forecast
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
  # Remove "interface": "e*"; to let Waybar auto-detect the active interface
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
  });

  waybarStyle = pkgs.writeText "waybar-style" (builtins.readFile ./style.css);

in {
systemd.user.services.waybar = {
    description = "Waybar status bar";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];


    path = with pkgs; [
      bash coreutils procps gawk gnugrep gnused bc jq curl lm_sensors
      rocmPackages.rocm-smi playerctl pulseaudio dunst libnotify
      wireplumber findutils yad audacious sox systemd util-linux
      brightnessctl
    ];

    serviceConfig = {
      ExecStart = "${pkgs.waybar}/bin/waybar -c ${waybarConfig} -s ${waybarStyle}";
      Restart = "always";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP XDG_SESSION_TYPE";
    };
  };

}
