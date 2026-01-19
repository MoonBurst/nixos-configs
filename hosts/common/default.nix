{
  config,
  pkgs,
  lib,
  niri-flake,
  cypkgs,
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
  services.gvfs.enable = true;

nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 14d";
};

nix.optimise = {
  automatic = true;
  dates = [ "weekly" ];
};

services.btrfs.autoScrub = {
  enable = true;
  interval = "monthly";
  fileSystems = [ "/" ];
};


  # ====================================================================
  # AUTO UPDATER
  # ====================================================================
# Automatic System Upgrades
system.autoUpgrade = {
  enable = true;
  flake = "path:/home/moonburst/nixos-config#${config.networking.hostName}";
  flags = [ "--update-input" "nixpkgs" "-v" ];
  dates = "11:00";
  randomizedDelaySec = "30min";
  allowReboot = false;
};

# Failure Notification Service
systemd.services."notify-update-failure" = {
  description = "Capture logs and send critical desktop notification on upgrade failure";
  script = ''
    LOG_FILE="/home/moonburst/UPDATE_FAILED.txt"
    USER_NAME="moonburst"
    USER_ID=$(id -u "$USER_NAME")

    echo "--- NIXOS AUTO-UPDATE FAILED ON $(date) ---" > "$LOG_FILE"
    /run/current-system/sw/bin/journalctl -u nixos-upgrade.service -n 50 --no-pager >> "$LOG_FILE"
    chown "$USER_NAME":users "$LOG_FILE"

    if [ -S "/run/user/$USER_ID/bus" ]; then
      /run/current-system/sw/bin/systemd-run \
        --user --machine="$USER_NAME@.host" \
        /run/current-system/sw/bin/notify-send -u critical \
        "SYSTEM UPDATE FAILED" \
        "Logs saved to $LOG_FILE"
    fi
  '';
  serviceConfig.Type = "oneshot";
};

# Link the Notification to the Upgrade Service
systemd.services.nixos-upgrade.unitConfig.OnFailure = "notify-update-failure.service";

# Automatic Cleanup: Remove error file if a subsequent update succeeds
systemd.services.nixos-upgrade.postStop = ''
  if [ "$SERVICE_RESULT" = "success" ]; then
    rm -f /home/moonburst/UPDATE_FAILED.txt
  fi
'';


  # ====================================================================
  # S.M.A.R.T MONITORING
  # ====================================================================

services.smartd = {
  enable = true;
  # Use 'defaults.monitored' as a single path to the string option
  defaults.monitored = ''
    -a \                       # -a: Monitor all SMART properties (Health, Pre-failure, and usage)
    -o on \                  # -o on: Enable Automatic Offline Data Collection to find bad sectors during idle
    -S on \                  # -S on: Enable Attribute Autosave to preserve SMART data across power cycles
    -n standby,q \      # -n standby,q: Skip checks if disk is sleeping; 'q' hides "skipping" logs
    -s (S/../.././02) \    # -s: Schedule a 'Short' self-test every day at 02:00 AM
    -M exec \             # -M exec: Run the following script instead of sending email
    ${let
      notifyScript = pkgs.writeShellScript "smartd-notify" ''
        for bus in /run/user/*/bus; do
          if [ -S "$bus" ]; then
            UID_NUM=$(echo "$bus" | cut -d'/' -f4)
            USER_NAME=$(id -nu "$UID_NUM")

            # Extract display environment variables from the user's active session
            USER_DISPLAY=$(grep -z '^DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')
            USER_WAYLAND=$(grep -z '^WAYLAND_DISPLAY=' /proc/$(pgrep -u "$UID_NUM" -n)/environ | cut -d= -f2- | tr -d '\0')

            # Send the alert to the user's notification daemon
            ${pkgs.sudo}/bin/sudo -u "$USER_NAME" \
              DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
              DISPLAY="$USER_DISPLAY" \
              WAYLAND_DISPLAY="$USER_WAYLAND" \
              ${pkgs.libnotify}/bin/notify-send -u critical \
              "SMART Disk Alert" "$SMARTD_MESSAGE"
          fi
        done
      '';
    in "${notifyScript}"}
  '';
};



  # ====================================================================
  # PROGRAMS, SHELLS, and THEME FIXES
  # ====================================================================

  # Sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
programs.dconf.profiles.user.databases = [{
  settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  settings."org/gnome/desktop/interface".gtk-theme = "Moon-Burst-Theme";
  lockAll = true; # This prevents user-level overrides from taking effect
}];
programs.dconf.enable = true;


  # Zsh configuration
  programs.zsh.enable = true;
  programs.zsh.autosuggestions.enable=true;
  programs.zsh.syntaxHighlighting.enable=true;
  programs.zsh.histSize=100000;
  programs.zsh.promptInit = builtins.readFile ./zshprompt.sh;
  environment.sessionVariables = rec {
    XDG_CURRENT_DESKTOP = "sway";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "sway";
    EDITOR = "nano";
	TERMINAL = "kitty";
	QT_QPA_PLATFORMTHEME = "qt6ct";
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
    HISTFILE = "${ZDOTDIR}/history";

    # Application-specific XDG paths
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
      "libvirtd"
    ];

    shell = pkgs.zsh;
  };


#====================================================================
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
    qimgv
    olm
    element-desktop
    steam-run
    zenity
    # --- Btrfs Tools
    btrfs-progs
    btrfs-assistant

    # --- Wayland Utilities
    quickshell
    waybar
    grim
    slurp
    wl-clipboard
    satty
    wtype
    wlrctl
    playerctl
    dunst
    swaylock
    swayidle
    swaybg
    python3
    smartmontools

    # --- Desktop/Theming
    nemo
    kdePackages.kate
    lxqt.pavucontrol-qt
    bluez-tools
    qt5.qtwayland
    qt6Packages.qt6ct

    # --- Applications/Communication
    sox
    mpv
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
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
#    (pkgs.callPackage ../../packages/datacorn.nix {})
  ];

              nixpkgs.config.permittedInsecurePackages = [
                "olm-3.2.16"
              ];

}

