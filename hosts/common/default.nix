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
  # SOPS
  # ====================================================================
sops = {
  defaultSopsFile = ../../secrets.yaml;
  age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";

  secrets.sops_key = {
    neededForUsers = true;
  };
};
  # ====================================================================
  # SERVICES AND HARDWARE
  # ====================================================================

  #---Graphics/Display ---
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  hardware.graphics.enable = true;                         # Enable GPU acceleration (OpenGL/Vulkan)
  hardware.graphics.enable32Bit = true;                   # Enable 32-bit graphics (required for Steam)
  programs.corectrl.enable = true;                        # Enable CPU/GPU performance and fan control
  security.polkit.enable = true;                          # Allow unprivileged apps to talk to privileged ones
  services.dbus.enable = true;                            # Enable system messaging for desktop apps
  services.gnome.gnome-keyring.enable = true;             # Enable secure password and SSH key storage
  security.pam.services.sway.enableGnomeKeyring = true;   # Allow Sway to unlock the keyring on login
  programs.browserpass.enable = true;                     # Enable 'pass' integration for browsers
  programs.fuse.userAllowOther = true;                    # Allow non-root users to share mounted drives

  #--- Display Manager
  services.displayManager.ly.enable = true;
  services.displayManager.sessionPackages = [pkgs.niri];

  # Audio: PipeWire (Full Setup)
security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = false;
    jack.enable = true;

    extraConfig.pipewire."10-quantum-size" = {
      "context.properties" = {
        "default.clock.min-quantum" = 512;
      };
    };

    extraConfig.pipewire."99-input-denoising" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Noise Suppressed Source";
            "media.name" = "Noise Suppressed Source";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "rnnoise";
                  plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                  label = "noise_suppressor_mono";
                  control = {
                    "VAD Threshold (%)" = 95.0;
                    "VAD Grace Period (ms)" = 200;
                    "Retroactive VAD Grace (ms)" = 200;
                  };
                }
              ];
            };
            "capture.props" = {
              "node.name" = "capture.rnnoise_source";
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "rnnoise_source";
              "media.class" = "Audio/Source";
            };
          };
        }
      ];
    };
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
  fileSystems = [
    "/"
    "/mnt/3TBHDD"
    "/mnt/nvme1tb"
    "/mnt/main_backup"
  ];
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
    /run/current-system/sw/bin/journalctl -u nixos-upgrade.service -n 100 --no-pager >> "$LOG_FILE"
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
        p.libxshmfence
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

    kitty # gpu-accelerated terminal
    fastfetch # system info display
    gnome-system-monitor # graphical task manager
    s-tui # cpu stress/monitor tool
    nano # basic text editor
    git # version control system
    github-cli # github command line
    gnupg # encryption/signing tool
    jq # json processor
    bc # cli calculator
    rsync # file sync utility
    rclone # cloud storage sync
    procps # process management tools
    psmisc # process utilities (killall)
    gawk # pattern scanning/processing
    ripgrep # fast text search
    dict # dictionary client
    libsecret # password storage library
    kdePackages.polkit-kde-agent-1 # auth dialog agent
    linux-firmware # hardware driver binaries
    nix-prefetch-github # nix hash fetcher
    unar # archive extractor
    zip # zip compressor
    unzip # zip extractor
    cliphist # clipboard history manager
    lm_sensors # hardware temp monitor
    usbutils # usb device info
    cargo # rust build system
    libnotify # notification library
    qimgv # fast image viewer
    olm # matrix encryption library
    element-desktop # matrix chat client
    steam-run # run binaries in fhs
    zenity # cli dialog boxes
    webp-pixbuf-loader # webp image thumbnails
    gdk-pixbuf # gtk image library
    rnnoise-plugin # mic noise suppression
    lsp-plugins # audio signal processing
    ncdu #file managerment location/size checks
    # --- Btrfs Tools
    btrfs-progs # btrfs filesystem tools
    btrfs-assistant # btrfs gui manager

    # --- Wayland Utilities
    waybar # wayland status bar
    grim # wayland screenshot tool
    slurp # region selector tool
    wl-clipboard # wayland clipboard utility
    satty # screenshot editor
    wtype # virtual keystroke tool
    wlrctl # wayland compositor tool
    playerctl # media player controller
    dunst # notification daemon
    swaylock # wayland screen locker
    swayidle # idle management daemon
    swaybg # wallpaper setter
    python3 # python interpreter
    smartmontools # drive health monitor

    # --- Desktop/Theming
    nemo # gtk file manager
    kdePackages.kate # advanced text editor
    pavucontrol # audio volume mixer
    bluez-tools # bluetooth cli tools
    qt5.qtwayland # qt5 wayland support
    qt6Packages.qt6ct # qt6 configuration tool

    # --- Applications/Communication
    sox # audio processing tool
    mpv # versatile media player
    audacious # lightweight audio player
    vivaldi # feature-rich web browser
    vesktop # optimized discord client
    evolution # email/calendar suite
    authenticator # 2fa code generator

    # --- Screencasting / Portals / Compositor Fixes
    niri # scrollable tiling compositor
    obs-studio # screen recording/streaming
    pipewire # modern audio/video server
    xdg-desktop-portal # desktop integration portal
    #xdg-desktop-portal-gnome # gnome portal backend
    xdg-desktop-portal-gtk # gtk portal backend
    xdg-desktop-portal-wlr # wlroots portal backend
    xdg-utils # desktop integration tools

    # --- Other Tools
    syncthing # p2p file sync
    pass # unix password manager
    sops #secrets manager


    sherlock-launcher
    (pkgs.callPackage ../../packages/sherlock-clipboard.nix {})
#    (pkgs.callPackage ../../packages/datacorn.nix {})


  ];

              nixpkgs.config.permittedInsecurePackages = [
                "olm-3.2.16"
              ];

}
