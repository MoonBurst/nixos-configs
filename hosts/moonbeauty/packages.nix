{ pkgs, config, lib, ... }:

let
  cinny-stylix = pkgs.makeDesktopItem {
    name = "Cinny-Stylix";
    desktopName = "Cinny (Matrix)";
    genericName = "Discord-like Matrix Client";
    exec = '' ${pkgs.brave}/bin/brave --app=https://dev.cinny.in --class=cinny-stylix'';
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
            /* Stylix Colors Injection */
            --background-primary: #${config.lib.stylix.colors.base00};
            --text-normal: #${config.lib.stylix.colors.base05};
            --brand-experiment: #${config.lib.stylix.colors.base0D};
          }
        '';
        plugins = {};
      };
    };
  };

  # --- Browser Theme Injection ---
  # References your theme.nix colors via config.lib.stylix.colors
  home.file.".config/vivaldi/custom.css".text = ''
    :root, [data-theme='dark'], .cinny {
      --bg: #${config.lib.stylix.colors.base00};
      --fg: #${config.lib.stylix.colors.base05};      /* Yellow */
      --fg-soft: #${config.lib.stylix.colors.base07}; /* Grey/White fallback */
      --accent: #${config.lib.stylix.colors.base0D};  /* Purple */

      /* Specific Cinny UI Overrides */
      --sidebar-color: #${config.lib.stylix.colors.base01} !important;
      --bg-color: #${config.lib.stylix.colors.base00} !important;
      --primary-text-color: #${config.lib.stylix.colors.base05} !important;
      --secondary-text-color: #${config.lib.stylix.colors.base07} !important;
      --accent-color: #${config.lib.stylix.colors.base0D} !important;

      /* Cinny Color Palette Overrides */
      --cp-color-text-primary: #${config.lib.stylix.colors.base05} !important;
      --cp-color-text-secondary: #${config.lib.stylix.colors.base07} !important;
      --cp-color-bg-surface: #${config.lib.stylix.colors.base00} !important;
    }

    /* Simple global injection for web pages */
    html, body {
      background-color: var(--bg) !important;
      color: var(--fg) !important;
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
   # swayidle                    # Idle management
    satty                       # Screenshot editor
    sherlock-launcher           # App launcher
    vicinae                     # Niri-compatible launcher
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
    protonup-qt                 # Proton manager
    btrfs-assistant             # Btrfs GUI
    kdePackages.kate             # Text editor (QT)
    kdePackages.kio-extras       # Kate file-browser support

    # --- 3D Printing & Design ---
    cura-appimage               # 3D Slicing
    orca-slicer                 # Modern 3D Slicing
    openscad                    # Programmatic 3D design

    # --- Tools Stylix can theme ---
    hyprpicker                  # Color picker
   # cinny-desktop
  ];

  home.stateVersion = "25.11";
}
