# ./quickshell.nix
# Universal self-contained NixOS module for Quickshell, Himalaya, Cliphist, MPD, and Overlays
{ config, pkgs, lib, ... }:

let
  normalUsers = lib.attrNames (lib.filterAttrs (name: u: u.isNormalUser) config.users.users);
  primaryUser = if (builtins.length normalUsers > 0) then (builtins.head normalUsers) else "root";
in
{
#This is so when the lockscreen is unlocked, PAM is valid
  security.pam.services.quickshell = {
    enableGnomeKeyring = true;
    text = ''
      auth     include      login
      account  include      login
      session  include      login
      password include      login
    '';
  };

  # Required for Borg mounts (-o allow_other) in UnifiedMonitor.qml
  programs.fuse.userAllowOther = true;

  # Passwordless sudo rules mapped dynamically to whatever user is compiling the flake
  security.sudo.extraRules = lib.singleton {
    users = normalUsers;
    commands = [
      # Systemctl Maintenance (Reset Failed Services button)
      {
        command = "/run/current-system/sw/bin/systemctl reset-failed";
        options = [ "NOPASSWD" ];
      }

      # Nix Garbage Collection (GC button)
      {
        command = "/run/current-system/sw/bin/nix-collect-garbage";
        options = [ "NOPASSWD" ];
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # 2. FONTS
  # ---------------------------------------------------------------------------
  fonts.packages = with pkgs; [
    fira
    fira-code
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
  ];

  # ---------------------------------------------------------------------------
  # 3. SYSTEM PACKAGES
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Core Runtimes & Interpreters (Pure Lua / Luajit, no Python)
    luajit
    jq
    curl

    # Music & Media (MPD, MPRIS, Audio)
    mpd
    mpd-mpris
    mpc
    playerctl
    trash-cli
    pipewire
    wireplumber

    # Clipboard & Notifications
    cliphist
    wl-clipboard
    libnotify

    # Email & Password Storage
    himalaya
    sops
    pass

    # Quickshot Screenshot, Watermark & OCR
    imagemagick
    tesseract

    # Screen Capture / Recording
    wf-recorder

    # System Health, Backups & Hardware Monitoring
    borgbackup
    fuse3
    iproute2
    iputils
    lm_sensors
    pciutils
    procps
    xdg-utils
  ];

  #I'm assuming you have MPD already from before this. If you don't, go ahead and enable this.
  services.mpd.enable = false;
  #Music path for MPD
  environment.etc."mpd.conf".text = ''
    music_directory     "/home/${primaryUser}/Music"
    playlist_directory  "/home/${primaryUser}/.config/mpd/playlists"
    db_file             "/home/${primaryUser}/.local/share/mpd/tag_cache"
    state_file          "/home/${primaryUser}/.local/share/mpd/state"
    sticker_file        "/home/${primaryUser}/.local/share/mpd/sticker.sql"
    auto_update         "yes"

    audio_output {
      type            "pipewire"
      name            "PipeWire Sound Server"
      mixer_type      "software"
    }
  '';

  # ---------------------------------------------------------------------------
  # 5. SYSTEMD USER SERVICES
  # ---------------------------------------------------------------------------
  systemd.user.services = {
    # Text clipboard stream watcher
    cliphist-text = {
      description = "Cliphist text clipboard watcher";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist -max-items 100 store";
        Restart = "always";
        RestartSec = "2s";
      };
    };

    # Image clipboard stream watcher
    cliphist-images = {
      description = "Cliphist image clipboard watcher";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist -max-items 50 store";
        Restart = "always";
        RestartSec = "2s";
      };
    };

    # Music Player Daemon user service
    mpd = {
      description = "Music Player Daemon";
      wantedBy = [ "default.target" ];
      after = [ "pipewire.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon /etc/mpd.conf";
        Restart = "on-failure";
      };
      # Self-contained runtime workspace generation loop using environmental paths
      preStart = ''
        mkdir -p $HOME/.config/mpd/playlists
        mkdir -p $HOME/.local/share/mpd
      '';
    };

    # MPD MPRIS Bridge (allows Quickshell Music capsule to control MPD)
    mpd-mpris = {
      description = "MPD MPRIS bridge daemon for Quickshell media controls";
      wantedBy = [ "default.target" ];
      after = [ "mpd.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.mpd-mpris}/bin/mpd-mpris -no-instance";
        Restart = "on-failure";
        RestartSec = "3s";
      };
    };
  };
}
