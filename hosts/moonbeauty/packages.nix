{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # --- Communication & Web ---
    vivaldi                     # Main browser
    vesktop                     # Discord with better Linux support
    element-desktop             # Matrix client
    jami                        # Distributed chat
    nicotine-plus               # Music/Soulseek client
    evolution                   # Email/Calendar

    # --- Media & Graphics ---
    mpv                         # Video player
    audacious                   # Music player
    krita                       # Digital painting/Photo editing
    gdk-pixbuf                  # Image library
    webp-pixbuf-loader          # WebP support for GTK
    lsp-plugins                 # Audio processing
    rnnoise-plugin              # Mic noise suppression

    # --- Wayland / Niri Desktop ---
    niri                        # Your compositor
    waybar                      # Status bar
    swaybg                      # Wallpaper management
    swaylock                    # Screen locker
    swayidle                    # Idle management
    cliphist                    # Clipboard history
    grim                        # Screenshot tool
    slurp                       # Region selector
    satty                       # Screenshot editor
    playerctl                   # Media key control
    wlrctl                      # Wayland control
    wtype                       # Virtual keystroke tool
    sherlock-launcher           # App launcher
    vicinae                     # Niri-compatible launcher
    wl-clipboard             #wl-copy/paste
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})

    # --- Hardware Control & Gaming ---
    corectrl                    # AMD GPU control
    openrgb-with-all-plugins    # RGB lighting
    rocmPackages.rocm-smi       # AMD GPU monitoring
    gamescope                   # Steam micro-compositor
    mangohud                    # FPS/System overlay
    protonup-qt                 # Proton GE manager
    obs-studio                  # Recording/Streaming
    obs-cli                     # OBS command line control
    pavucontrol                 # Volume mixer
    qt6Packages.qt6ct           # QT theming

    # --- 3D Printing & Development ---
    cura-appimage               # 3D Slicing
    orca-slicer                 # Modern 3D Slicing
    openscad                    # Programmatic 3D design
    cargo                       # Rust build tool
    python3                     # Scripting

    # --- VM & File Management ---
    looking-glass-client        # High-performance VM display
    dnsmasq                     # VM networking
    nemo                        # File manager
    btrfs-assistant             # Btrfs/Snapper GUI
    syncthing                   # P2P file sync
    rclone                      # Cloud storage sync
    borgbackup                  # Deduplicating backups
  ];

  # Theming Configuration
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    settings."org/gnome/desktop/interface".gtk-theme = "Moon-Burst-Theme";
    lockAll = true;
  }];
}
