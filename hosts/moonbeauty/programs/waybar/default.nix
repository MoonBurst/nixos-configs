{ pkgs, lib, ... }:

let
  mkScript = name: source: pkgs.writeShellScript name (builtins.readFile source);

  gpuScript = mkScript "gpu_readout.sh" ./modules/gpu_readout.sh;
  cpuScript = mkScript "cpu_readout.sh" ./modules/cpu_readout.sh;
  ramScript = mkScript "ram_readout.sh" ./modules/ram_readout.sh;
  weatherScript = mkScript "weather_readout.sh" ./modules/weather_readout.sh;
  dunstScript = mkScript "dunst_count.sh" ./modules/dunst_count.sh;
  alarmScript = mkScript "alarm.sh" ./modules/alarm.sh;

  # Absolute path to your portal script for maximum reliability
  musicScriptPath = "/home/moonburst/nixos-config/hosts/moonbeauty/programs/waybar/modules/music_portal.sh";

  waybarConfig = pkgs.writeText "waybar-config" (builtins.toJSON {
    layer = "top";
    position = "top";
    spacing = 2;

    modules-left = [
      "idle_inhibitor"
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
      "bluetooth"
      "custom/gpu_readout"
      "custom/cpu_readout"
      "custom/ram_readout"
      "tray"
    ];

    "custom/music" = {
      "format" = "󰎆 {}";
      "interval" = 2;
      "exec" = "${pkgs.audacious}/bin/audtool current-song 2>/dev/null || echo 'Stopped'";

      # LEFT CLICK: Open/Focus Window
      "on-click" = "bash ${musicScriptPath} ui";

      # MIDDLE CLICK: Smart Toggle (Play/Pause without restarting)
      "on-click-middle" = "bash ${musicScriptPath}";

      # RIGHT CLICK: Add Music
      "on-click-right" = "bash ${musicScriptPath} add";

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
      "interval" = 2; "tooltip" = false;
    };

    "custom/weather" = {
      "exec" = "${pkgs.coreutils}/bin/timeout 2s ${pkgs.bash}/bin/bash ${weatherScript} | ${pkgs.coreutils}/bin/head -n 1";
      "interval" = 600; "tooltip" = false;
    };

    "custom/dunst_count" = {
      "exec" = "${pkgs.bash}/bin/bash ${dunstScript}";
      "interval" = 5;
      "on-click" = "${pkgs.dunst}/bin/dunstctl set-paused toggle";
      "tooltip" = false;
    };

    "idle_inhibitor" = {
      "format" = "{icon}";
      "format-icons" = { "activated" = ""; "deactivated" = ""; };
      "tooltip" = false;
    };

    "clock" = { "format" = "{:%I:%M:%p}"; "interval" = 5; "tooltip" = false; };
    "clock#day" = { "format" = "{:%a %d %b}"; "tooltip-format" = "<tt><small>{calendar}</small></tt>"; };

    "network" = {
      "min-length" = 25; "max-length" = 25; "interface" = "e*";
      "format-wifi" = " {bandwidthDownBytes}  {bandwidthUpBytes} ";
      "format-ethernet" = "{bandwidthDownBytes}  | {bandwidthUpBytes} ";
      "format-linked" = "(No IP)"; "format-disconnected" = "";
      "on-click" = "iwmenu -l custom --launcher-command \"sherlock\"";
      "tooltip" = false; "interval" = 1;
    };

    "pulseaudio" = {
      "format" = "{volume}% {icon}";
      "on-click" = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      "format-icons" = { "default" = [ "" "" "" ]; };
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

    wants = [ "audacious.service" ];
    after = [ "audacious.service" ];

    path = with pkgs; [
      bash coreutils procps gawk gnugrep gnused bc jq curl lm_sensors
      rocmPackages.rocm-smi playerctl pulseaudio dunst libnotify
      wireplumber findutils yad audacious sox systemd util-linux
    ];

    serviceConfig = {
      ExecStart = "${pkgs.waybar}/bin/waybar -c ${waybarConfig} -s ${waybarStyle}";
      Restart = "always";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
      PassEnvironment = "DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP XDG_SESSION_TYPE";
    };
  };
}
