{ config, pkgs, lib, ... }:

{
  security.pam.services.quickshell = {
    enableGnomeKeyring = true;
    text = ''
      auth     include      login
      account  include      login
      session  include      login
      password include      login
    '';
  };

  programs.fuse.userAllowOther = true;

  security.sudo.extraRules = lib.mkIf (config.home-manager.users != {}) [{
    users = builtins.attrNames config.home-manager.users;
    commands = [
      {
        command = "/run/current-system/sw/bin/systemctl reset-failed";
        options = [ "NOPASSWD" ];
      }
      {
        command = "/run/current-system/sw/bin/nix-collect-garbage";
        options = [ "NOPASSWD" ];
      }
    ];
  }];

  fonts.packages = with pkgs; [
    fira
    fira-code
    noto-fonts
    noto-fonts-color-emoji
    font-awesome
  ];

  environment.systemPackages = with pkgs; [
    luajit jq curl mpd mpd-mpris mpc playerctl trash-cli
    pipewire wireplumber cliphist wl-clipboard libnotify
    himalaya sops pass imagemagick tesseract wf-recorder
    borgbackup fuse3 iproute2 iputils lm_sensors pciutils procps xdg-utils
  ];

  services.mpd.enable = false;
  systemd.sockets.mpd.enable = false;

  systemd.user.services = {
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
  };

  home-manager.sharedModules = [
    ({ config, pkgs, ... }: {
      systemd.user.startServices = "sd-switch";

      home.file.".config/mpd/mpd.conf".text = ''
        music_directory     "${config.home.homeDirectory}/Music"
        playlist_directory  "${config.home.homeDirectory}/.config/mpd/playlists"
        db_file             "${config.home.homeDirectory}/.local/share/mpd/tag_cache"
        state_file          "${config.home.homeDirectory}/.local/share/mpd/state"
        sticker_file        "${config.home.homeDirectory}/.local/share/mpd/sticker.sql"
        auto_update         "yes"

        # Universal dual-binding matrix accommodates network TCP and private UNIX sockets
        bind_to_address     "localhost"
        bind_to_address     "${config.home.homeDirectory}/.config/mpd/socket"

        audio_output {
          type            "pipewire"
          name            "PipeWire Sound Server"
          mixer_type      "software"
        }
      '';

      systemd.user.services = {
        cliphist-text = {
          Unit = {
            Description = "Cliphist text clipboard watcher";
            After = [ "graphical-session.target" ];
          };
          Install = { WantedBy = [ "graphical-session.target" ]; };
          Service = {
            X-Restart-Triggers = [ "${config.home.homeDirectory}/.config/mpd/mpd.conf" ];
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist -max-items 100 store";
            Restart = "always";
            RestartSec = "2s";
          };
        };

        cliphist-images = {
          Unit = {
            Description = "Cliphist image clipboard watcher";
            After = [ "graphical-session.target" ];
          };
          Install = { WantedBy = [ "graphical-session.target" ]; };
          Service = {
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist -max-items 50 store";
            Restart = "always";
            RestartSec = "2s";
          };
        };

        mpd = {
          Unit = {
            Description = "Music Player Daemon";
            After = [ "pipewire.service" "sound.target" ];
          };
          Install = { WantedBy = [ "default.target" ]; };
          Service = {
            ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon ${config.home.homeDirectory}/.config/mpd/mpd.conf";
            Restart = "always";
            RestartSec = "3s";
          };
        };

        mpd-mpris = {
          Unit = {
            Description = "MPD MPRIS bridge daemon for Quickshell media controls";
            After = [ "mpd.service" ];
            Wants = [ "mpd.service" ];
          };
          Install = { WantedBy = [ "default.target" ]; };
          Service = {
            ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -S ${config.home.homeDirectory}/.config/mpd/socket ]; do ${pkgs.coreutils}/bin/sleep 0.5; done'";
            ExecStart = "${pkgs.mpd-mpris}/bin/mpd-mpris -no-instance -network unix -host ${config.home.homeDirectory}/.config/mpd/socket";
            Restart = "always";
            RestartSec = "5s";
          };
        };
      };
    })
  ];
}
