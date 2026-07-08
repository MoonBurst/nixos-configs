{ config, pkgs, ... }:

{

  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture
      wlrobs
    ];
  };

  environment.systemPackages = [ pkgs.obs-cmd ];

  systemd.user.services.obs = {
    description = "OBS Studio Headless/Auto-start Service";
    after = [ "graphical-session.target" "pipewire.service" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.StartLimitIntervalSec = 3;

    serviceConfig = {
      ExecStart = "${pkgs.obs-studio}/bin/obs -d --startvirtualcam --minimize-to-tray";
      # Clean restarts on actual crashes, staying stopped on clean logouts
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStopSec = 5;
    };
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';
}
