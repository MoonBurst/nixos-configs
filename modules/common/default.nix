{ config, pkgs, lib, ... }:

{
  # Set your time zone.
  time.timeZone = "America/Matamoros";
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # This value determines the NixOS release.
  system.stateVersion = "25.05"; # <--- SEMICOLON ADDED HERE
  
  # ====================================================================
  # NETWORKING
  # ====================================================================
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true; # <--- SEMICOLON ADDED HERE
  
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
  security.pam.services.sway.enableGnomeKeyring = true; # <--- SEMICOLON ADDED HERE
  
  
  #--- Display Manager
  services.displayManager.ly.enable = true; # <--- SEMICOLON ADDED HERE
#services.getty.users.tty1 = "moonburst";
#Audio: PipeWire (Full Setup) ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  }; # <--- SEMICOLON ADDED HERE

  # --- Wayland/App Compatibility ---

  
  # --- XDG Portal Configuration ---
  xdg.portal = {
    enable = true;
    configPackages = [ pkgs.xdg-desktop-portal-wlr ]; 
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; 
  }; # <--- SEMICOLON ADDED HERE
  
  # ====================================================================
  # PROGRAMS, SHELLS, and THEME FIXES
  # ====================================================================
  
  # Sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; 
  }; # <--- SEMICOLON ADDED HERE

  # Zsh configuration
  programs.zsh.enable = true; # <--- SEMICOLON ADDED HERE

  # GnuPG / SSH Agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  }; # <--- SEMICOLON ADDED HERE

  # Qt/GTK Theming Fix
  environment.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt5ct"; 
    GTK_THEME="Moon-Burst-Theme";
    GDK_BACKEND = "wayland,x11"; 
  }; # <--- SEMICOLON ADDED HERE
  
  # NOTE: The package list from the first definition (neofetch, git) is
  # now merged into the final, large list at the bottom.
  
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
  }; # <--- SEMICOLON ADDED HERE
  
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
  }; # <--- SEMICOLON ADDED HERE
  
  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  nixpkgs.config.allowUnfree = true; # <--- SEMICOLON ADDED HERE
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  ''; # <--- SEMICOLON ADDED HERE
  
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
  }; # <--- SEMICOLON ADDED HERE
  
  # ====================================================================
  # NIX-LD
  # ====================================================================
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    #put programs here
  ]; # <--- SEMICOLON ADDED HERE
  
  # NOTE: Merged both 'environment.systemPackages' definitions into this single list.
  environment.systemPackages = with pkgs; [
    # --- Packages from first definition ---
    git # A tool everyone needs (from first block)
    neofetch
    
    # --- System Utilities/Shell
    kitty
    fastfetch
    gnome-system-monitor
    s-tui
    nano
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
    audacious
    vivaldi
    vesktop
    evolution

    # --- Other Tools
    pass
    unar
    zip
    unzip
    sox
    geany
    sherlock-launcher
    cliphist
   # fchat-horizon
   # moon-burst-theme
  ]; # <--- FINAL SEMICOLON ADDED HERE TO RESOLVE LINE 232 ERROR
  
  # The final closing brace MUST NOT have a semicolon.
}
