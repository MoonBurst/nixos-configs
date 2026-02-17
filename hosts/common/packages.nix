{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # --- Version Control ---
    git                         # The heart of your flake
    github-cli                  # Managing repos from terminal
    nix-prefetch-github          # Getting hashes for flake inputs

    # --- CLI Essentials ---
    curl                         # Transferring data
    wget                         # Downloading files
    rsync                        # Fast file copying
    jq                           # JSON processor
    ripgrep                      # Better than grep
    psmisc                       # fuser, killall, etc.
    gawk                         # Pattern scanning/processing
    bc                           # Calculator for scripts

    # --- Archives ---
    zip                          # Zip compression
    unzip                        # Zip extraction
    unar                         # Universal archiver

    # --- System Monitoring & Hardware ---
    ncdu                         # Disk usage analyzer
    s-tui                        # CPU monitor/stress test
    smartmontools                # Drive health (SMART)
    htop                         # Process monitor
    usbutils                     # lsusb
    pciutils                     # lspci
    linux-firmware               # Hardware blobs
    tree

    # --- Base UI Essentials ---
    libnotify                    # Sending desktop notifications
    fastfetch                    # System info on terminal start
    kitty                        # Your GPU-accelerated terminal

    # --- GUI Apps & Editors ---
    kdePackages.kate             # Your missing editor
    kdePackages.kio-extras       # Needed for Kate's file-browser sidebar
  ];

  fonts = {
    packages = with pkgs; [
      fira-sans                  # Clean sans-serif
      font-awesome               # Icons for Waybar
      roboto                     # Standard UI font
      jetbrains-mono              # Coding font
      noto-fonts                 # Universal coverage
      noto-fonts-color-emoji      # Emojis
      material-symbols           # UI Icons
      material-icons              # More UI Icons
      # Nerd Fonts (Specific icons for terminal/Waybar)
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.enable = true;
  };
}
