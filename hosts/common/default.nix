{ config, pkgs, lib, niri-flake, custom-programs, ... }: 
let
  # The old 'my-packages' let binding is removed as packages are now exposed via overlay in root flake.nix
in

{
  imports = [
    niri-flake.nixosModules.niri
  ];
    
  time.timeZone = "America/Matamoros";
  i18n.defaultLocale = "en_US.UTF-8";
  system.stateVersion = "25.15"; 
    
  nixpkgs.overlays = [
    niri-flake.overlays.niri 
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
    
  services.displayManager.sessionPackages = [ pkgs.niri ];
    
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
      xdg-desktop-portal-gtk 
      xdg-desktop-portal-gnome
      xdg-desktop-portal-wlr # All three portal backends enabled
    ];
    
    config = {
      common = {
        #"org.freedesktop.impl.portal.ScreenCast" = "wlr"; 
      };
      niri = {
        default = [ 
           "gtk"
           "wlr"
           "gnome" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gtk" ]; 
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
      };
    };
  };

  systemd.user.services."xwayland-satellite-autostart" = {
    description = "XWayland Satellite Autostart for Niri";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.xwayland-satellite-stable}/bin/xwayland-satellite";
      Restart = "on-failure";
      RestartSec = 5;
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

  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "niri";
    QT_QPA_PLATFORMTHEME = "qt5ct"; 
    GTK_THEME="Moon-Burst-Theme"; 
    GDK_BACKEND = "wayland,x11"; 
    OBS_PLATFORM = "wayland"; 
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
    max-jobs = 14 # 🚀 Set build jobs to 14
  ''; 
    
  # ====================================================================
  # APPIMAGE STUFF (Unchanged)
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
    xdg-desktop-portal-gnome 
    xdg-desktop-portal-gtk 
    xdg-desktop-portal-wlr
    xdg-utils 

    xwayland-satellite-stable

    # --- Other Tools
    syncthing
    pass
    geany
 
 
 
 
    (custom-programs.packages.${pkgs.system}.sherlock-launcher) 
    (custom-programs.packages.${pkgs.system}.fchat-horizon)
  ]; 
}
