{ pkgs, lib, ... }: {
  stylix = {
    enable = true;
    autoEnable = true;
    enableReleaseChecks = false;
    polarity = "dark";
    # image = ./assets/chibimoon.png;

    targets.qt.enable = true;
    targets.qt.platform = "qtct";
    targets.gtk.enable = true;

    iconTheme = {
      enable = true;
      # We override the Nix store package and "bake in" the black and blue colors
      package = (pkgs.numix-icon-theme.overrideAttrs (oldAttrs: {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.gnused pkgs.findutils ];

        postInstall = ''
          echo "Recoloring Numix icons to Black and Blue..."
          find $out/share/icons/Numix -name "*.svg" -type f -exec sed -i \
            -e 's/#f2bb64/#2F2F2F/gI' \
            -e 's/#ea9036/#40BFFF/gI' \
            -e 's/#f9f9f9/#CECB00/gI' \
            {} +
        '';
      }));
      dark = "Numix";
      light = "Numix-Light";
    };

    cursor = {
      package = pkgs.nightdiamond-cursors;
      name = "NightDiamond-Blue";
      size = 24;
    };

    base16Scheme = {
      base00 = "#1E1E1E"; # Black
      base01 = "#0f0f0f";
      base02 = "#544E5A";
      base03 = "#003399";
      base04 = "#4d4e93";
      base05 = "#CECB00"; # Yellow
      base06 = "#ebdbb2";
      base07 = "#fbf1c7";
      base08 = "#ff0000";
      base09 = "#fe8019";
      base0A = "#fabd2f";
      base0B = "#b8bb26";
      base0C = "#8ec07c";
      base0D = "#675DDB"; # Blue
      base0E = "#675DDB";
      base0F = "#ff8019";
    };

    fonts = {
      sizes = {
        applications = 14;
        desktop = 14;
        popups = 14;
      };
      serif = { package = pkgs.roboto; name = "Roboto Serif"; };
      sansSerif = { package = pkgs.fira-sans; name = "Fira Sans"; };
      monospace = { package = pkgs.nerd-fonts.jetbrains-mono; name = "JetBrainsMono Nerd Font"; };
      emoji = { package = pkgs.noto-fonts-color-emoji; name = "Noto Color Emoji"; };
    };
  };
}
