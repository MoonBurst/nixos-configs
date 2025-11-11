{
  config,
  pkgs,
  lib,
  niri-flake,
  ...
}: let

in {
  imports = [
  
  ];

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  nixpkgs.overlays = [
  ];

  # ====================================================================
  # NETWORKING
  # ====================================================================
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  # ====================================================================
  # SERVICES AND HARDWARE
  # ====================================================================

  #---Graphics/Display ---
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  programs.corectrl.enable = true;
  security.polkit.enable = true;
  services.dbus.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sway.enableGnomeKeyring = true;
  programs.browserpass.enable = true;

  #--- Display Manager
  services.displayManager.ly.enable = true;

  services.displayManager.sessionPackages = [pkgs.niri];

  #Audio: PipeWire (Full Setup) ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # --- XDG Portal Configuration (SCREENCAPTURE FIX) ---
  xdg.portal = {
    enable = true;
    wlr.enable = true;

    extraPortals = with pkgs; [
	xdg-desktop-portal-wlr
	xdg-desktop-portal-gtk
    #xdg-desktop-portal-gnome
      
    ];

    config = {
      common = {
        #"org.freedesktop.impl.portal.ScreenCast" = "wlr";
      };
    };
  };

  # GnuPG / SSH Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  services.openssh.enable = true;

  # ====================================================================
  # PROGRAMS, SHELLS, and THEME FIXES
  # ====================================================================

  # Sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Zsh configuration
  programs.zsh.enable = true;
  programs.zsh.autosuggestions.enable=true;
  programs.zsh.syntaxHighlighting.enable=true;
  programs.zsh.histSize=100000;
  programs.zsh.promptInit = builtins.readFile ./zshprompt.sh;
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "sway";
    QT_QPA_PLATFORMTHEME = "qt5ct";
    GTK_THEME = "Moon-Burst-Theme";
    GDK_BACKEND = "wayland,x11";
    OBS_PLATFORM = "wayland";
    
  # ====================================================================
  # XDG RULES
  # ====================================================================
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    ZDOTDIR = "$HOME/nixos-config/hosts/common";
    HISTFILE = "$ZDOTDIR/history";

    # Application-specific XDG paths
    CARGO_HOME = "$XDG_DATA_HOME/cargo";
    DOTNET_CLI_HOME = "$XDG_DATA_HOME/dotnet";
    GOPATH = "$XDG_DATA_HOME/go";
    GRADLE_USER_HOME = "$XDG_DATA_HOME/gradle";
    GNUPGHOME = "$XDG_DATA_HOME/gnupg";
    GTK2_RC_FILES = "$XDG_CONFIG_HOME/gtk-2.0/gtkrc";
    NPM_CONFIG_CACHE = "$XDG_CACHE_HOME/npm";
    NPM_CONFIG_INIT_MODULE = "$XDG_CONFIG_HOME/npm/config/npm-init.js";
    NUGET_PACKAGES = "$XDG_CACHE_HOME/NuGetPackages";
    PASSWORD_STORE_DIR = "$XDG_DATA_HOME/pass";
    RUSTUP_HOME = "$XDG_DATA_HOME/rustup";
  };

  # ====================================================================
  # USER CONFIGURATION
  # ====================================================================
  users.users.moonburst = {
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
    ];

    shell = pkgs.zsh;
  };

  # ====================================================================
  # FONTS (Unchanged)
  # ====================================================================
  fonts = {
    packages = with pkgs; [
      fira-sans
      font-awesome
      roboto
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.jetbrains-mono
      jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      material-symbols
      material-icons
    ];
    fontconfig.enable = true;
  };

  # ====================================================================
  # ENVIRONMENT AND PACKAGES (Settings)
  # ====================================================================
  nixpkgs.config.allowUnfree = true;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
    max-jobs = 14 # Max cores allowed for building
  '';

  # ====================================================================
  # APPIMAGE STUFF
  # ====================================================================
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override {
      extraPkgs = p: [
        p.xorg.libxshmfence
        # p.libxshmfence32
      ];
    };
  };

  # ====================================================================
  # NIX-LD (Unchanged)
  # ====================================================================
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
  stdenv.cc.cc.lib
  zlib
    #put programs here
  ];

  # ====================================================================
  # ENVIRONMENT AND PACKAGES (List)
  # ====================================================================

  environment.systemPackages = with pkgs; [
    # --- System Utilities/Shell
    kitty
    fastfetch
    gnome-system-monitor
    s-tui
    nano
    git
    github-cli
    gnupg
    jq
    bc
    rsync
    rclone
    procps
    psmisc
    gawk
    ripgrep
    dict
    libsecret
    kdePackages.polkit-kde-agent-1
    linux-firmware
    nix-prefetch-github
    unar
    zip
    unzip
    cliphist
    lm_sensors
    usbutils
    cargo
    libnotify
    # --- Btrfs Tools
    btrfs-progs

    # --- Wayland Utilities
    waybar
    grim
    slurp
    wl-clipboard
    satty
    wtype
    playerctl
    dunst
    swaylock
    swayidle
    swaybg

    # --- Desktop/Theming
    nemo
    lxqt.pavucontrol-qt
    bluez-tools
    qt5.qtwayland
    qt6Packages.qt6ct

    # --- Applications/Communication
    sox
    audacious
    vivaldi
    vesktop
    evolution
    authenticator

    # --- Screencasting / Portals / Compositor Fixes
    niri
    obs-studio
    pipewire
    xdg-desktop-portal
   #xdg-desktop-portal-gnome
    xdg-desktop-portal-gtk
    xdg-desktop-portal-wlr
    xdg-utils

    # --- Other Tools
    syncthing
    pass
    geany

    sherlock-launcher
    (pkgs.callPackage ../../packages/fchat-horizon.nix {})
  ];
}
