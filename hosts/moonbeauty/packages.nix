{ pkgs, config, lib, nixpkgs-unstable, inputs, ... }:

let
  unstable = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

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
 inputs.horizon.packages.${pkgs.system}.horizon-electron



    # --- Unstable Packages ---
    unstable.dolphin-emu
    unstable.archipelago
    unstable.poptracker
    unstable.quickshell

    # --- Communication & Social ---
    jami
    nicotine-plus
    evolution
    mission-center
    matrixApp

    # --- Media & Graphics ---
    audacious
    krita

    # --- System & Utilities ---
    btrfs-assistant

    # --- Development & Productivity ---
    kdePackages.kate
    protonup-qt

    # --- 3D Printing & CAD ---
    cura-appimage
    orca-slicer
    openscad
  ]; # <-- This single closing bracket now correctly terminates the entire block


  # --- Desktop Entry for Launcher ---
  xdg.desktopEntries = {
    matrix-brave = {
      name = "Matrix (Brave)";
      genericName = "Matrix Client";
      exec = "${matrixApp}/bin/matrix";
      icon = "matrix";
      terminal = false;
      categories = [ "Network" "Chat" ];
      settings = {
        StartupWMClass = "matrix-app";
      };
    };
  };
}
