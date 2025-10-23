# /etc/nixos/configuration.nix

{ config, pkgs, lib, ... }:

# The entire configuration body MUST be wrapped in one attribute set { ... }
{
  # ====================================================================
  #  MODULE IMPORTS
  # ====================================================================
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./mounts.nix
      ./fonts.nix
    ];

  # ====================================================================
  #  BOOT AND SYSTEM CONFIGURATION
  # ====================================================================
  
  # Bootloader (systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # --- AMDGPU/ROCm Kernel Parameters ---
  boot.kernelParams = [
    "amdgpu.vm_fragment_size=9"
    "fbcon=rotate:2"
    "amdgpu.ppfeaturemask=0xffffffff"
    "cma=512M"
  ];
  boot.initrd.kernelModules = [ 
    "amdgpu" 
  ];

  # Set your time zone.
  time.timeZone = "America/Matamoros";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # This value determines the NixOS release.
  system.stateVersion = "25.05"; 
  
  # ====================================================================
  # NETWORKING
  # ====================================================================
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # --- Bluetooth Service ---
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

  #--- Display Manager
  services.displayManager.ly.enable = true;  
  # --- Audio: PipeWire (Full Setup) ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # --- Wayland/App Compatibility ---
    services.dbus.enable = true;
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.ly.enableGnomeKeyring = true;
  # --- XDG Portal Configuration ---
  xdg.portal = {
    enable = true;
    configPackages = [ pkgs.xdg-desktop-portal-wlr ]; 
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; 
  };
  

security.polkit.enable = true;
programs.corectrl.enable = true;
  # ====================================================================
  # USER CONFIGURATION
  # ====================================================================
  users.users.moonburst = {
    isNormalUser = true;
    description = "MoonBurst";
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "audio" 
      "video" 
      "input"
      "render"
      "corectrl" 
    ];
    
    shell = pkgs.zsh;
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

programs.browserpass.enable = true;
programs.gamescope.capSysNice = true;
programs.gamemode.enable = true;  

hardware.steam-hardware.enable = true;
programs.steam.enable = true;
programs.steam.dedicatedServer.openFirewall = true;

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
    # Add any missing dynamic libraries for unpackaged programs
    # here, NOT in environment.systemPackages
  ];
  
  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  nixpkgs.config.allowUnfree = true;
	nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  
    environment.systemPackages = with pkgs; [
    # --- System Utilities/Shell ---
    kitty
    fastfetch
    s-tui
    nano
    git
    github-cli
    gnupg
    jq
    bc
    rsync
    procps
    psmisc
    gawk
    ripgrep
    dict    
    libsecret
    rocmPackages.rocm-smi 
	corectrl
	lxqt.lxqt-policykit
    linux-firmware
    # --- Btrfs Tools ---
    btrfs-progs
    # --- Gaming/GPU/Emulation ---
    gamescope
    mesa
    protonup-qt 
 
    
    # --- Wayland Utilities ---
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
    mangohud
    
    # --- Desktop/Theming ---
    nemo
    lxqt.pavucontrol-qt 
    bluez-tools 
    
    qt5.qtwayland   
    #libsForQt5.qt5ct
    qt6ct
    
    # --- Applications/Communication ---
    audacious 
    vivaldi
    vesktop
    
    # --- Other Tools ---
    pass
    unar
    zip
    unzip
    sox
    geany
    sherlock-launcher

  ];
  
}
