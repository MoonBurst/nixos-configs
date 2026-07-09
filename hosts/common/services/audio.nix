{ config, pkgs, ... }:

{
  # Sound subsystem architecture configuration
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;

    extraConfig.pipewire."99-input-routing" = {
      "context.modules" = [
        {
          name = "libpipewire-module-echo-cancel";
          args = {
            "node.description" = "Clear Voice Microphone";
            "source.props" = {
              "node.name" = "clear_voice_source";
              "media.class" = "Audio/Source";
              "audio.position" = [ "MONO" ];
            };
            "aec.args" = {
              "webrtc.noise_suppression" = true;
              "webrtc.gain_control" = true;
              "webrtc.extended_filter" = true;
            };
          };
        }
      ];
    };

    wireplumber.extraConfig."99-force-clear-voice" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~.*" ; } #all streams use this
          ];
          actions = {
            update-props = {
              "target.object" = "clear_voice_source";
            };
          };
        }
      ];
    };
  };

  environment.systemPackages = [
    pkgs.pavucontrol
    pkgs.pipewire
  ];
}
