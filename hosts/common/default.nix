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
    # --- System Utilities/Shell ---
    fuse3                          # FUSE 3 implementation
    kitty                          # gpu-accelerated terminal
    fastfetch                      # system info display
    gnome-system-monitor           # graphical task manager
    s-tui                          # cpu stress/monitor tool
    nano                           # basic text editor
    git                            # version control system
    github-cli                     # github command line
    gnupg                          # encryption/signing tool
    rsync                          # file sync utility
    rclone                         # cloud storage sync
    psmisc                         # process utilities (killall)
    ripgrep                        # fast text search
    dict                           # dictionary client
    libsecret                      # password storage library
    kdePackages.polkit-kde-agent-1 # auth dialog agent
    linux-firmware                 # hardware driver binaries
    nix-prefetch-github            # nix hash fetcher
    unar                           # archive extractor
    zip                            # zip compressor
    unzip                          # zip extractor
    cliphist                       # clipboard history manager
    usbutils                       # usb device info
    cargo                          # rust build system
    libnotify                      # notification library
    qimgv                          # fast image viewer
    olm                            # matrix encryption library
    element-desktop                # matrix chat client
    steam-run                      # run binaries in fhs
    webp-pixbuf-loader             # webp image thumbnails
    gdk-pixbuf                     # gtk image library
    rnnoise-plugin                 # mic noise suppression
    lsp-plugins                    # audio signal processing
    ncdu                           # file management location/size checks

    # --- Btrfs Tools ---
    btrfs-progs                    # btrfs filesystem tools
    btrfs-assistant                # btrfs gui manager

    # --- Wayland Utilities ---
    waybar                         # wayland status bar
    grim                           # wayland screenshot tool
    slurp                          # region selector tool
    wl-clipboard                   # wayland clipboard utility
    satty                          # screenshot editor
    wtype                          # virtual keystroke tool
    wlrctl                         # wayland compositor tool
    playerctl                      # media player controller
    swaylock                       # wayland screen locker
    swayidle                       # idle management daemon
    swaybg                         # wallpaper setter
    python3                        # python interpreter
    smartmontools                  # drive health monitor

    # --- Desktop/Theming ---
    nemo                           # gtk file manager
    kdePackages.kate               # advanced text editor
    pavucontrol                    # audio volume mixer
    bluez-tools                    # bluetooth cli tools
    qt5.qtwayland                  # qt5 wayland support
    qt6Packages.qt6ct              # qt6 configuration tool

    # --- Applications/Communication ---
    mpv                            # versatile media player
    audacious                      # lightweight audio player
    vivaldi                        # feature-rich web browser
    vesktop                        # optimized discord client
    evolution                      # email/calendar suite
    authenticator                  # 2fa code generator

    # --- Screencasting / Portals / Compositor Fixes ---
    niri                           # scrollable tiling compositor
    obs-studio                     # screen recording/streaming
    pipewire                       # modern audio/video server
    xdg-desktop-portal             # desktop integration portal
    xdg-desktop-portal-gtk         # gtk portal backend
    xdg-desktop-portal-wlr         # wlroots portal backend
    xdg-utils                      # desktop integration tools

    # --- Other Tools ---
    syncthing                      # p2p file sync
    pass                           # unix password manager
    sops                           # secrets manager
    sherlock-launcher
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
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

  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 100000;
    promptInit = builtins.readFile ./zshprompt.sh;
  };

  environment.sessionVariables = rec {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "sway";
    EDITOR = "nano";
    TERMINAL = "kitty";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    GTK_THEME = "Moon-Burst-Theme";
    GDK_BACKEND = "wayland,x11";
    OBS_PLATFORM = "wayland";

    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    ZDOTDIR = "$HOME/nixos-config/hosts/common";
    HISTFILE = "${ZDOTDIR}/history";

    CARGO_HOME = "${XDG_DATA_HOME}/cargo";
    DOTNET_CLI_HOME = "${XDG_DATA_HOME}/dotnet";
    GOPATH = "${XDG_DATA_HOME}/go";
    GRADLE_USER_HOME = "${XDG_DATA_HOME}/gradle";
    GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
    GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc";
    NPM_CONFIG_CACHE = "${XDG_CACHE_HOME}/npm";
    NPM_CONFIG_INIT_MODULE = "${XDG_CONFIG_HOME}/npm/config/npm-init.js";
    NUGET_PACKAGES = "${XDG_CACHE_HOME}/NuGetPackages";
    PASSWORD_STORE_DIR = "${XDG_DATA_HOME}/pass";
    RUSTUP_HOME = "${XDG_DATA_HOME}/rustup";
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
