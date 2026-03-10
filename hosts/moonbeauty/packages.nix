{ pkgs, config, lib, ... }:

{
  # 1. Create a Desktop Launcher for Brave in App Mode
  xdg.desktopEntries.cinny-brave = {
    name = "Cinny (Brave)";
    genericName = "Matrix Client";
    # Using the absolute path to make sure it finds the right binary
    # and adding flags for WebRTC/Media support.
    # Update this line in your package.nix
exec = "${pkgs.brave}/bin/brave --app=https://dev.cinny.in/ --use-fake-ui-for-media-stream --enforce-webrtc-ip-permission-check";
    icon = "matrix";
    terminal = false;
    categories = [ "Network" "InstantMessaging" ];
    settings.StartupWMClass = "dev.cinny.in";
  };

  # 2. Add only the media-specific support packages
  home.packages = with pkgs; [
    # These ensure the browser has the right "pipes" for audio/video
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    # Your existing packages (Brave removed from here to avoid collision)
    jami
    nicotine-plus
    evolution
    audacious
    krita
    qview
    pavucontrol
    swaylock-effects
    satty
    sherlock-launcher
    vicinae
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
    protonup-qt
    btrfs-assistant
    kdePackages.kate
    cura-appimage
    orca-slicer
    openscad
    hyprpicker
  ];

  home.stateVersion = "25.11";
}
