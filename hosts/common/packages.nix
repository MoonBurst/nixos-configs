{ pkgs, inputs, ... }: {
  environment.systemPackages = with pkgs; [
    # --- Version Control & Dev (Non-GUI) ---
    git                         # The heart of your flake
    github-cli                  # Managing repos from terminal
    nix-prefetch-github         # Getting hashes for flake inputs
    cargo                       # Rust build tool
    python3                     # Scripting
    kdePackages.qt6gtk2
    libsForQt5.qtstyleplugins

    # --- CLI Essentials & Networking ---
    curl                        # Transferring data
    wget                        # Downloading files
    rsync                     # Fast file copying
    jq                          # JSON processor
    ripgrep                     # Better than grep
    psmisc                      # fuser, killall, etc.
    gawk                        # Pattern scanning/processing
    bc                          # Calculator for scripts
    xdg-utils                   # Desktop integration tools
    tree                        # Directory visualization
    wl-clipboard                # wl-copy/paste
    libnotify                   # Sending desktop notifications
    micro
    vlc


    # --- Archives ---
    zip                         # Zip compression
    unzip                       # Zip extraction
    unar                        # Universal archiver

    # --- System & Hardware (Non-GUI / Backend) ---
    corectrl                    # AMD GPU control
    openrgb-with-all-plugins    # RGB lighting
    rocmPackages.rocm-smi       # AMD GPU monitoring
    gamescope                   # Steam micro-compositor
    looking-glass-client        # VM display
    dnsmasq                     # VM networking
    syncthing                   # P2P file sync
    rclone                      # Cloud storage sync
    borgbackup                  # Deduplicating backups
    ncdu                        # Disk usage analyzer
    s-tui                       # CPU monitor/stress test
    smartmontools               # Drive health (SMART)
    htop                        # Process monitor
    usbutils                    # lsusb
    linux-firmware              # Hardware blobs

    # --- Wayland & Compositor ---
    swaybg                      # Wallpaper management
    cliphist                    # Clipboard history
    grim                        # Screenshot tool
    slurp                       # Region selector
    playerctl                   # Media key control
    wlrctl                      # Wayland control
    wtype                       # Virtual keystroke tool
    fastfetch                   # System info
    nemo                        # File manager (GTK)
    # --- System Libraries & Audio Engines ---
    gdk-pixbuf                  # Image library
    webp-pixbuf-loader          # WebP support for GTK
    rnnoise-plugin              # Mic noise suppression
    qt6Packages.qt6ct           # QT theming logic
    pass                        # Password manager

    swaylock-effects                    # Screen locker with blur and aesthetic effects
    satty                               # Modern screenshot annotation tool
    qview                               # Minimalist, fast image viewer
    pavucontrol                         # PulseAudio/PipeWire volume mixer (essential for debugging mic/speakers)


    sops
    age
    mkpasswd
    ssh-to-age

    inputs.moon-numix.packages.${pkgs.system}.default
    pkgs.kitty.terminfo
    # --- Fonts ---
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    symbola
    unifont        # Ultimate BMP coverage
    unifont_upper  # Ultimate SMP coverage
waybar
vesktop
  ];
}
