# --- packages.nix ---
{ pkgs, config, lib, nixpkgs-unstable, ... }:

let
  unstable = import nixpkgs-unstable {
    system = pkgs.system;
    config.allowUnfree = true;
  };

  quickshellWithPulse = unstable.quickshell.override { enablePulse = true; };

  # 1. Pull the script out into a reusable variable
  matrixApp = pkgs.writeShellScriptBin "matrix" ''
    exec ${pkgs.brave}/bin/brave \
      --app=https://moonburst.net \
      --class=matrix-app \
      --name=matrix-app \
      --user-data-dir="$HOME/.config/matrix-brave" \
      --no-first-run \
      --no-singleton-window \
      --enable-features=UseOzonePlatform \
      --ozone-platform=wayland
  '';
in
{
  home.packages = with pkgs; [
    # --- Unstable Packages ---
    unstable.dolphin-emu                # GameCube/Wii emulator
    unstable.archipelago                # Multi-game randomizer
    unstable.poptracker                 # Tracker for randomizers
    quickshellWithPulse

    # --- Communication & Social ---
    jami                                # Peer-to-peer video calling and chat
    nicotine-plus                       # Graphical client for the Soulseek file-sharing network
    evolution                           # Professional email and calendar suite
    mission-center

    # --- Detached Cinny Instance ---
    matrixApp                           # 2. Add the variable to packages here

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
      exec = "${matrixApp}/bin/matrix"; # 3. Reference the absolute store path here
      icon = "matrix";
      terminal = false;
      categories = [ "Network" "Chat" ];
      settings = {
        StartupWMClass = "matrix-app";
      };
    };
  };
}
