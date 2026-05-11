# --- packages.nix ---
{ pkgs, config, lib, nixpkgs-unstable, ... }:

let
  unstable = nixpkgs-unstable.legacyPackages.${pkgs.system};
in
{
  home.packages = with pkgs; [
    # --- Unstable Packages ---
    unstable.dolphin-emu                # GameCube/Wii emulator
    unstable.archipelago                # Multi-game randomizer
    unstable.poptracker                 # Tracker for randomizers
    # --- Communication & Social ---
    jami                                # Peer-to-peer video calling and chat
    nicotine-plus                       # Graphical client for the Soulseek file-sharing network
    evolution                           # Professional email and calendar suite
    mission-center

    # --- Detached Cinny Instance ---
    (writeShellScriptBin "matrix" ''
      exec ${pkgs.brave}/bin/brave \
        --app=https://moonburst.net \
        --class=matrix-app \
        --user-data-dir="$HOME/.config/matrix-brave" \
        --enable-features=UseOzonePlatform \
        --ozone-platform=wayland
    '')


    # --- Media & Graphics ---
    audacious                           # Lightweight, "Winamp-style" audio player
    krita                               # Professional digital painting and illustration tool


    # --- System & Utilities ---
    sherlock-launcher                   # Minimalist application runner/launcher
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
    matrix-brave = {
      name = "Matrix (Brave)";
      genericName = "Matrix Client";
      exec = "matrix";
      icon = "matrix";
      terminal = false;
      categories = [ "Network" "Chat" ];
      settings = {
        StartupWMClass = "matrix-app";
      };
    };
  };
}
