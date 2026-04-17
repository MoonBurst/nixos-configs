{ config, pkgs, ... }:

{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;

    extraConfig.pipewire."99-input-routing" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "OBS CLEANED (Virtual Mic)";
            "capture.props" = {
              "node.name" = "obs_cleaned_sink";
              "media.class" = "Audio/Sink";
              "audio.position" = [ "FL" "FR" ];
            };
            "playback.props" = {
              "node.name" = "obs_cleaned_source";
              "media.class" = "Audio/Source";
              "audio.position" = [ "FL" "FR" ];
            };
          };
        }
      ];
    };

    wireplumber.extraConfig."10-default-input" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "obs_cleaned_source"; } ];
          actions = {
            update-props = {
              "priority.driver" = 2000;
              "priority.session" = 2000;
            };
          };
        }
      ];
    };
  };

  environment.systemPackages = with pkgs; [ pavucontrol ];
}
