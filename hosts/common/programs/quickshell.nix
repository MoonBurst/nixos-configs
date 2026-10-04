# ./quickshell.nix
# Unified, self-contained NixOS module for Quickshell, Himalaya, Cliphist, MPD, and Overlays
{ config, pkgs, lib, ... }:

let
  username = "moonburst";
in
{
  # ---------------------------------------------------------------------------
  # 1. SECURITY & PERMISSIONS
  # ---------------------------------------------------------------------------
  # PAM service for Quickshell lockscreen authentication (LockManager.qml)
  security.pam.services.quickshell = {};

  # Required for Borg mounts (-o allow_other) in UnifiedMonitor.qml
  programs.fuse.userAllowOther = true;

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
    # Core Runtimes & Interpreters
    luajit
    (python3.withPackages (ps: with ps; [ ]))
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

  # ---------------------------------------------------------------------------
  # 4. MPD CONFIGURATION
  # ---------------------------------------------------------------------------
  services.mpd.enable = false;

  environment.etc."mpd.conf".text = ''
    music_directory     "/home/${username}/Music"
    playlist_directory  "/home/${username}/.config/mpd/playlists"
    db_file             "/home/${username}/.local/share/mpd/tag_cache"
    state_file          "/home/${username}/.local/share/mpd/state"
    sticker_file        "/home/${username}/.local/share/mpd/sticker.sql"
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
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 500";
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
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50";
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
      preStart = ''
        mkdir -p /home/${username}/.config/mpd/playlists
        mkdir -p /home/${username}/.local/share/mpd
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
