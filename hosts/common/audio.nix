{ pkgs, ... }:

{
  # ====================================================================
  # PIPEWIRE AND AUDIO
  # ====================================================================

  # Crucial for fixing "robotic" or stuttering audio.
  # It allows PipeWire to acquire real-time priority.
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;      # ALSA compatibility
    alsa.support32Bit = true; # 32-bit app support
    pulse.enable = true;     # PulseAudio emulation
    jack.enable = true;      # JACK emulation

    # Tuning for stability and low-latency (Fixes Discord "robot voice")
    extraConfig.pipewire = {
      "92-low-latency" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 512;
          "default.clock.max-quantum" = 2048;
        };
      };
    };
  };

  # Enable dconf so EasyEffects can save settings
  programs.dconf.enable = true;

  # Audio processing and plugin packages
  environment.systemPackages = with pkgs; [
    pipewire
    easyeffects
    lsp-plugins
    zam-plugins
    rnnoise
    deepfilternet
    pavucontrol # Highly recommended for debugging which app is stuttering
  ];
}
