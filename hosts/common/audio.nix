{ pkgs, ... }:

{
  # ====================================================================
  # PIPEWIRE AND AUDIO
  # ====================================================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;      # ALSA compatibility
    alsa.support32Bit = true; # 32-bit app support
    pulse.enable = true;     # PulseAudio emulation
    jack.enable = true;      # JACK emulation
  };

  # Enable dconf so EasyEffects can save settings
  programs.dconf.enable = true;

  # Audio processing and plugin packages
  environment.systemPackages = with pkgs; [
    easyeffects
    lsp-plugins
    zam-plugins
    rnnoise
    deepfilternet
  ];
}
