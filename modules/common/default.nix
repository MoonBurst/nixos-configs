{ config, pkgs, lib, ... }:
let

  my-packages = import ../../flake_programs/default.nix { inherit pkgs; }; 
in
{
	
  # Set your time zone.
  time.timeZone = "America/Matamoros";
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # This value determines the NixOS release.
  system.stateVersion = "25.05"; 
  
  #add imports for packages here===================


  nixpkgs.overlays = [
    (self: super: {
      # Use the packages from the my-packages set
      fchat-horizon = my-packages.fchat-horizon; 
	moon-burst-theme = super.callPackage ./moonburst-theme.nix {};
      
    })
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
  #Audio: PipeWire (Full Setup) ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  }; 

  # --- Wayland/App Compatibility ---
  # --- XDG Portal Configuration ---
  xdg.portal = {
    enable = true;
    configPackages = [ pkgs.xdg-desktop-portal-wlr ]; 
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; 
  }; 
  
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

  # GnuPG / SSH Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  }; 

  # Qt/GTK Theming Fix
  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt5ct"; 
    GTK_THEME="Moon-Burst-Theme";
    GDK_BACKEND = "wayland,x11"; 
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
  # FONTS
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
      noto-fonts-emoji
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      material-symbols
      material-icons
    ];
    fontconfig.enable = true;
  }; 
  
  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  nixpkgs.config.allowUnfree = true; 
  nix.extraOptions = ''
    experimental-features = nix-command flakes
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
  # NIX-LD
  # ====================================================================
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    #put programs here
  ]; 
  
  # ====================================================================
  # ENVIRONMENT AND PACKAGES
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

    # --- Desktop/Theming
    nemo
    lxqt.pavucontrol-qt
    bluez-tools
    qt5.qtwayland
    qt6ct

    # --- Applications/Communication
    sox
    audacious
    vivaldi
    vesktop
    evolution

    # --- Other Tools
    syncthing
    pass
    geany
    sherlock-launcher
    
    fchat-horizon
    moon-burst-theme
  ]; 
  
  
}
