{ config, pkgs, ... }:

{
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
              # This forces the internal WebRTC filter to hold the audio open
              # longer and prevents rapid cutting out / gating artifacting
              "webrtc.voice_detection" = true;
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
