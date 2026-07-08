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
    wantedBy = [ "graphical-session.target" ];
    unitConfig.StartLimitIntervalSec = 3;

    serviceConfig = {
      # Replaced --nosafe with --disable-shutdown-check to bypass the safe mode dialog
      ExecStart = "${pkgs.obs-studio}/bin/obs --disable-shutdown-check --startvirtualcam --minimize-to-tray";
      StandardOutput = "null";
      StandardError = "null";
      Restart = "always";
      RestartSec = 5;
    };
  };

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';
}
