{ config, pkgs, lib, ... }:

{
  # This module adds the custom theme package to the system's package list.
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "moon-burst-theme-link";
      paths = [
        (pkgs.runCommand "moon-burst-theme-dir" {} ''
          # 1. Create the required directory structure: $out/share/themes/THEME_NAME
          mkdir -p $out/share/themes/Moon-Burst-Theme
          
          # 2. Link the contents of your source folder to the new destination
          # This is what gets picked up by GTK via XDG_DATA_DIRS
          ln -s /etc/nixos/Moon-Burst-Theme/* $out/share/themes/Moon-Burst-Theme/
        '')
      ];
    })
  ];
}
