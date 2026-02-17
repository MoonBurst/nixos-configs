{
  config,
  pkgs,
  lib,
  niri-flake,
  cypkgs,
  inputs,
  ...
}: {
  imports = [
    ./services.nix
    ./zsh.nix
    inputs.sops-nix.nixosModules.sops
  ];

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = lib.mkDefault "auto";
    auto-optimise-store = true;
  };

  # ====================================================================
  # NETWORKING & HARDWARE (Common base)
  # ====================================================================
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # ====================================================================
  # USER CONFIGURATION
  # ====================================================================
  users.users.moonburst = {
    hashedPasswordFile = config.sops.secrets.sops_key.path;
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";
    extraGroups = [
    "networkmanager"
    "wheel"
    "audio"
    "video"
    "input"
    "render"
    "corectrl"
    "i2c"
    "libvirtd" ];
    shell = pkgs.zsh;
  };

  # ====================================================================
  # SOPS
  # ====================================================================
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
    secrets = {
      sops_key = {
        neededForUsers = true;
      };
      weather_api_key = { owner = "moonburst"; };
      weather_city = { owner = "moonburst"; };
    };
  };


  # ====================================================================
  # SYSTEM PACKAGES
  # ====================================================================
environment.systemPackages = with pkgs; [
  # --- Applications & Communication ---
  audacious                       # lightweight audio player
  authenticator                   # 2fa code generator
  element-desktop             # matrix chat client
  evolution                         # email/calendar suite
  mpv                                # versatile media player
  vesktop                          # optimized discord client
  vivaldi                            # feature-rich web browser

  # --- Development & Version Control ---
  cargo                             # rust build system
  git                                 # version control system
  github-cli                      # github command line
  nix-prefetch-github      # nix hash fetcher
  python3                       # python interpreter

  # --- File Management & Archives ---
  btrfs-assistant             # btrfs gui manager
  btrfs-progs                  # btrfs filesystem tools
  ncdu                           # file management location/size checks
  nemo                          # gtk file manager
  rclone                         # cloud storage sync
  rsync                          # file sync utility
  syncthing                   # p2p file sync
  unar                           # archive extractor
  unzip                          # zip extractor
  zip                              # zip compressor

  # --- Multimedia & Graphics ---
  gdk-pixbuf                     # gtk image library
  lsp-plugins                    # audio signal processing
  obs-studio                    # screen recording/streaming
  pavucontrol                 # audio volume mixer
  pipewire                      # modern audio/video server
  qimgv                         # fast image viewer
  rnnoise-plugin            # mic noise suppression
  webp-pixbuf-loader             # webp image thumbnails

  # --- Secrets & Security ---
  gnupg                       # encryption/signing tool
  libsecret                    # password storage library
  olm                            # matrix encryption library
  pass                           # unix password manager
  sops                           # secrets manager

  # --- Shell & System Utilities ---
  bluez-tools                    # bluetooth cli tools
  curl
  dict                                # dictionary client
  fastfetch                      # system info display
  fuse3                          # FUSE 3 implementation
  gawk
  gnome-system-monitor           # graphical task manager
  jq
   kdePackages.kate               # advanced text editor
   kdePackages.partitionmanager#partition manager
  kitty                           # gpu-accelerated terminal
  libnotify                      # notification library
  linux-firmware            # hardware driver binaries
  nano                           # basic text editor
  psmisc                        # process utilities (killall)
  ripgrep                        # fast text search
  s-tui                            # cpu stress/monitor tool
  smartmontools           # drive health monitor
  steam-run                  # run binaries in fhs
  usbutils                      # usb device info
  wget

  # --- Wayland & Niri Environment ---
  cliphist                       # clipboard history manager
  grim                           # wayland screenshot tool
  kdePackages.polkit-kde-agent-1 # auth dialog agent
  niri                             # scrollable tiling compositor
  playerctl                    # media player controller
  qt5.qtwayland           # qt5 wayland support
  qt6Packages.qt6ct    # qt6 configuration tool
  satty                         # screenshot editor
  sherlock-launcher    # app launcher
  (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
  slurp                        # region selector tool
  swaybg                    # wallpaper setter
  swayidle                  # idle management daemon
  swaylock                 # wayland screen locker
  waybar                   # wayland status bar
  wlrctl                      # wayland compositor tool
  wtype                     # virtual keystroke tool
  wl-clipboard
  xdg-desktop-portal                # desktop integration portal
  xdg-desktop-portal-gtk          # gtk portal backend
  xdg-desktop-portal-gnome    # recommended for evolution/libsecret
  xdg-desktop-portal-wlr         # wlroots portal backend
  xdg-utils                               # desktop integration tools
];

  # ====================================================================
  # PROGRAMS, SHELLS, and THEME FIXES
  # ====================================================================
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    settings."org/gnome/desktop/interface".gtk-theme = "Moon-Burst-Theme";
    lockAll = true;
  }];



environment.sessionVariables = let
  homePath = "/home/moonburst";
in rec {

};

  fonts = {
    packages = with pkgs; [
      fira-sans font-awesome roboto
      nerd-fonts._0xproto nerd-fonts.droid-sans-mono nerd-fonts.jetbrains-mono
      jetbrains-mono noto-fonts noto-fonts-color-emoji noto-fonts-cjk-sans
      noto-fonts-cjk-serif material-symbols material-icons papirus-icon-theme adwaita-icon-theme
    ];
    fontconfig.enable = true;
  };

  # ====================================================================
  # MISC PROGRAMS
  # ====================================================================
  programs.corectrl.enable = true;
  programs.browserpass.enable = true;
  programs.fuse.userAllowOther = true;
  programs.gnupg.agent = { enable = true; enableSSHSupport = true; };
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override { extraPkgs = p: [ p.libxshmfence ]; };
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib ];

  security.polkit.enable = true;
  security.rtkit.enable = true;
  security.pam.services.sway.enableGnomeKeyring = true;
  security.pam.services.ly.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
  nix.optimise = { automatic = true; dates = [ "weekly" ]; };
}
