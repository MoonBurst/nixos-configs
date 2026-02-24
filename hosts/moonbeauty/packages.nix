{ pkgs, ... }: {
  # --- Programs with dedicated Stylix/HM modules ---
  # Moving these here allows Stylix to generate their themes automatically
  programs = {
    obs-studio.enable = true;
    waybar.enable = true;
    kitty.enable = true;
    mpv.enable = true;
    mangohud.enable = true;
  };

  home.packages = with pkgs; [
    # --- Communication & Web ---
    vesktop                     # Discord (Stylix themes the client)
    element-desktop             # Matrix (Stylix themes the client)
  #  nheko                         # Matrix (Stylix themes the client)
    cinny
    jami                        # Distributed chat
    nicotine-plus               # Music/Soulseek client
    evolution                   # Email/Calendar
    (vivaldi.override { commandLineArgs = [ "--disable-features=AudioServiceSandbox" "--ozone-platform-hint=auto" "--log-level=3"];} )



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
    fastfetch                   # System info (Themes the logo/text)
  ];

  home.stateVersion = "25.11";
}
