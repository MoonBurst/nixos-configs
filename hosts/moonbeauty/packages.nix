# --- packages.nix ---
{ pkgs, config, lib, ... }:

{
  home.packages = with pkgs; [
    # --- Communication & Social ---
    jami                                # Peer-to-peer video calling and chat
    nicotine-plus                       # Graphical client for the Soulseek file-sharing network
    evolution                           # Professional email and calendar suite

# --- Detached Cinny Instance ---
(writeShellScriptBin "cinny-brave" ''
  exec ${pkgs.brave}/bin/brave \
    --app=https://moonburst.net \
    --class=cinny-app \
    --enable-features=UseOzonePlatform \
    --ozone-platform=wayland
'')

    # --- Media & Graphics ---
    audacious                           # Lightweight, "Winamp-style" audio player
    krita                               # Professional digital painting and illustration tool
    qview                               # Minimalist, fast image viewer
    pavucontrol                         # PulseAudio/PipeWire volume mixer (essential for debugging mic/speakers)

    # --- System & Utilities ---
    swaylock-effects                    # Screen locker with blur and aesthetic effects
    satty                               # Modern screenshot annotation tool
    sherlock-launcher                   # Minimalist application runner/launcher
    vicinae                             # Contact-finding utility
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {}) # Custom clipboard manager
    btrfs-assistant                     # GUI for managing Btrfs filesystems and Snapper snapshots
    hyprpicker                          # Color picker for Wayland/Hyprland

    # --- Development & Productivity ---
    kdePackages.kate                    # Powerful multi-document text editor
    protonup-qt                         # Tool to manage GE-Proton versions for Steam/Gaming

    # --- 3D Printing & CAD ---
    cura-appimage                       # Popular 3D printer slicer (AppImage version)
    orca-slicer                         # High-performance slicer based on Bambu/PrusaSlicer
    openscad                            # Programmatic 3D CAD modeler
  ];

  # --- Desktop Entry for Launcher ---
  xdg.desktopEntries = {
    cinny-brave = {
      name = "Cinny (Brave)";
      genericName = "Matrix Client";
      exec = "cinny-brave";
      icon = "cinny";                  # Pulls the icon from the system icon theme
      terminal = false;
      categories = [ "Network" "Chat" ];
      settings = {
        StartupWMClass = "cinny-app";  # Matches the --class flag in the script
      };
    };
  };

  home.stateVersion = "25.11";
}
