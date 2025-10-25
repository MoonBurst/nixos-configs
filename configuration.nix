# /etc/nixos/configuration.nix

{ config, pkgs, lib, ... }:

# The entire configuration body MUST be wrapped in one attribute set { ... }



#add imports for packages here===================
let
  my-packages = import /etc/nixos/default.nix { inherit pkgs; };
in

#=====================================


{
  # ====================================================================
  #  MODULE IMPORTS
  # ====================================================================
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./mounts.nix
      
    ];




nixpkgs.overlays = [
    (self: super: {
      # Use the packages from the my-packages set
      fchat-horizon = my-packages.fchat-horizon; 
      
    
	moon-burst-theme = super.callPackage ./moonburst-theme.nix {};
      
    })
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
    "fbcon=rotate:2" #--rotates screen
    "amdgpu.ppfeaturemask=0xffffffff" #--needed for corectrl
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
 
 
 
 
 
 
 
 
 
 security.polkit.debug = true;
 
 
 
 
 
 
 
 
 
 
 
 
 
 
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
  # CRON
  # ====================================================================  
  
services.cron = {
  enable = true;
  systemCronJobs = [
		#backs up music
		"0  12 * * * ~/scripts/cron_scripts/music-backup.sh >/dev/null 2>&1"
		#backs up passwords
		"0 0 * * 0 ~/scripts/cron_scripts/pass_copy.sh >/dev/null 2>&1"
		#pushes a backup to nextcloud
		"0 4 1 * * ~/scripts/cron_scripts/nextcloud_upload.sh >/dev/null 2>&1"
		#moves .desktop files from home folder to .local/share/applications (mostly for steam games) 
		"0 */4 * * * ~/scripts/cron_scripts/mv-.desktop-to-applications.sh >/dev/null 2>&1"
		#reminders
		"0 */4 * * * ~/scripts/cron_scripts/reminder.sh >/dev/null 2>&1"
		#github update
		"0 0 * * 0 /run/current-system/sw/bin/bash ~/scripts/github/github-updater.sh >> ~/scripts/github-updater.log >/dev/null 2>&1"
		#wallpaper switching
		"*/30 * * * * ~/scripts/cron_scripts/wallpaper.sh  >/dev/null 2>&1"
  ];
};


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
 
  ];
  
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
  
    environment.systemPackages = with pkgs; [
    # --- System Utilities/Shell ---
    cron
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
    rocmPackages.rocm-smi 
	corectrl
	kdePackages.polkit-kde-agent-1
    linux-firmware
	nix-prefetch-github

    # --- Btrfs Tools ---
    btrfs-progs
    # --- Gaming/GPU/Emulation ---
    gamescope
    mesa
    protonup-qt 
    obs-studio
    obs-studio-plugins.wlrobs
    obs-cli
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
    qt6ct
    
    # --- Applications/Communication ---
    audacious 
    vivaldi
    vesktop
    evolution
    # --- Other Tools ---
    pass
    unar
    zip
    unzip
    sox
    geany
    sherlock-launcher
    cliphist
    
    
    
    
      fchat-horizon
	  moon-burst-theme
  ];
}

