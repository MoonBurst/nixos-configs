{ config, pkgs, ... }:

let
  # V1: The Input Hub. Raw Mic -> V1. OBS listens here.
  V1 = "01. HUB (OBS Input)";
  V1_ID = "OBS_Virtual_Input_Cable";

  # V2: The Output Hub. OBS Filtered -> V2. Discord/Apps listen here.
  V2 = "02. OBS CLEANED (Virtual Mic)";
  V2_ID = "Discord_Virtual_Mic";
in
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;

    # This creates the virtual devices on startup
    extraConfig.pipewire."99-input-routing" = {
      "context.modules" = [
        # --- V1: SINK FOR OBS INPUT ---
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.name" = V1_ID;
            "node.description" = V1;
            "capture.props" = {
              "media.class" = "Audio/Sink"; # Apps (Mic) play to this
              "node.passive" = true;
            };
            "playback.props" = {
              "node.passive" = true;
            };
          };
        }

        # --- V2: SOURCE FOR DISCORD ---
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.name" = V2_ID;
            "node.description" = V2;
            "capture.props" = {
              "media.class" = "Audio/Sink"; # OBS Monitors to this
              "node.passive" = true;
            };
            "playback.props" = {
              "media.class" = "Audio/Source"; # Appears as a Microphone
              "device.class" = "filter";
              "node.role" = "Communication";
              "audio.position" = [ "FL" "FR" ];
              "node.passive" = true;
            };
          };
        }
      ];
    };
  };

  # Tools to manage the visual connections
  environment.systemPackages = with pkgs; [
    pavucontrol # Traditional volume mixer
    qpwgraph    # Visual patchbay (highly recommended)
    helvum      # Simple patchbay
  ];
}
