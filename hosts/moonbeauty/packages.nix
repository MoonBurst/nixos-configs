{ pkgs, config, lib, nixpkgs-unstable, inputs, ... }:

let
  unstable = import nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  horizon-electron = pkgs.writeShellScriptBin "horizon-electron" ''
    exec ${inputs.horizon.packages.${pkgs.stdenv.hostPlatform.system}.horizon-electron}/bin/horizon-electron --ozone-platform=wayland --password-store=gnome-libsecret "$@"
  '';

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
    horizon-electron

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
  ];

  # --- Desktop Entry for Launcher ---
  xdg.desktopEntries = {
    horizon = {
      name = "Horizon";
      genericName = "Horizon Launcher";
      exec = "${horizon-electron}/bin/horizon-electron %U";
      icon = "fchat-horizon";
      terminal = false;
      categories = [ "Game" ];
    };

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
