{ pkgs, config, lib, ... }:

let
  # Custom wrapper to run Cinny via Vivaldi to avoid the broken native package
  # Inherits your specific Vivaldi flags and applies a dedicated class for styling
  cinny-stylix = pkgs.makeDesktopItem {
    name = "Cinny-Stylix";
    desktopName = "Cinny (Matrix)";
    genericName = "Discord-like Matrix Client";
    exec = ''
      ${pkgs.brave}/bin/brave --app=https://app.cinny.in --class=cinny-stylix
    '';
    icon = "matrix";
    categories = [ "Network" "Chat" ];
    terminal = false;
  };
in
{
  # --- Programs with dedicated Stylix/HM modules ---
  # Moving these here allows Stylix to generate their themes automatically
  programs = {
    obs-studio.enable = true;
    waybar.enable = true;
    kitty.enable = true;
    mpv.enable = true;
    mangohud.enable = true;
    element-desktop.enable = true;
    # --- Vesktop & Vencord ---
    # Consolidated into the programs block to fix the "attribute defined twice" error
    vesktop = {
      enable = true;
      settings = {
        "discordBranch" = "stable";
        "firstRun" = false;
        "minimizeToTray" = "on";
        "arRPC" = "on";
        "useQuickCss" = true;
        "enabledThemes" = [ "stylix.css" ];
      };
      vencord.settings = {
        quickCss = ''
          @import url("https://raw.githubusercontent.com");
          :root {
            --server-columns: 3;
            --server-size: 35px;
            --server-spacing: 1px;
          }
        '';
        plugins = {};
      };
    };
  };

  # --- Browser Theme Injection ---
  # References your theme.nix colors via config.lib.stylix.colors
  home.file.".config/vivaldi/custom.css".text = ''
    :root {
      --bg: #${config.lib.stylix.colors.base00};
      --fg: #${config.lib.stylix.colors.base05};
      --accent: #${config.lib.stylix.colors.base0D};
    }
    /* Simple global injection for web pages */
    html, body {
      background-color: var(--bg) !important;
      color: var(--fg) !important;
    }
    /* Specific overrides for Cinny UI if using the wrapper */
    [data-theme='dark'] {
       --sidebar-color: #${config.lib.stylix.colors.base01} !important;
    }
  '';

#░█░█░█▀█░█▄░▄█░█▀▀
#░█▀█░█░█░█░▀░█░█▀▀
#░▀░▀░▀▀▀░▀░░░▀░▀▀▀
  home.packages = with pkgs; [
    # --- Custom Cinny Wrapper ---
    cinny-stylix

    # --- Communication & Web ---
    jami                        # Distributed chat
    nicotine-plus               # Music/Soulseek client
    evolution                   # Email/Calendar
    (vivaldi.override {
      commandLineArgs = [
        "--disable-features=AudioServiceSandbox"
        "--ozone-platform-hint=auto"
        "--log-level=3"
        "--force-dark-mode"
        "--enable-features=WebContentsForceDark"
      ];
    })

    # --- Media & Graphics ---
    audacious                   # Music player (GTK)
    krita                       # Digital painting (QT)
    qview                       # Image viewer
    pavucontrol                 # Volume mixer (GTK)


    # --- Desktop GUI Utilities ---
    swaylock                    # Screen locker
    swayidle                    # Idle management
    satty                       # Screenshot editor
    sherlock-launcher           # App launcher
    vicinae                     # Niri-compatible launcher
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
    protonup-qt                 # Proton manager
    nemo                        # File manager (GTK)
    btrfs-assistant             # Btrfs GUI
    kdePackages.kate             # Text editor (QT)
    kdePackages.kio-extras       # Kate file-browser support

    # --- 3D Printing & Design ---
    cura-appimage               # 3D Slicing
    orca-slicer                 # Modern 3D Slicing
    openscad                    # Programmatic 3D design

    # --- Tools Stylix can theme ---
    hyprpicker                  # Color picker
    fastfetch                   # System info
  ];

  home.stateVersion = "25.11";
}
