{ config, pkgs, ... }:

{
  # 1. Install OBS with essential plugins
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture # Easiest way to grab your virtual sinks
      wlrobs                     # Required if you are on Wayland
    ];
  };

  # 2. Define the systemd user service
  systemd.user.services.obs = {
    description = "OBS Studio Headless/Auto-start Service";
    
    # Wait until the graphical session and pipewire are ready
    after = [ "graphical-session.target" "pipewire.service" ];
    wantedBy = [ "graphical-session.target" ];

    serviceConfig = {
      # --startvirtualcam starts the camera immediately
      # --minimize starts it in the tray so it's not in your way
      ExecStart = "${pkgs.obs-studio}/bin/obs --startvirtualcam --minimize";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # 3. Ensure Virtual Camera driver is loaded at boot
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';
}
