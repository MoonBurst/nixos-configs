{ config, pkgs, ... }:

{
  # Install the command-line controller system-wide
  environment.systemPackages = [ pkgs.mpc ];

  # Disable the system-wide service completely to prevent conflicts
  services.mpd.enable = false;

  # Declaratively generate the MPD configuration file
  environment.etc."mpd.conf".text = ''
    music_directory     "/home/moonburst/Music"
    playlist_directory  "/home/moonburst/.config/mpd/playlists"
    db_file             "/home/moonburst/.local/share/mpd/tag_cache"
    state_file          "/home/moonburst/.local/share/mpd/state"
    sticker_file        "/home/moonburst/.local/share/mpd/sticker.sql"
    auto_update         "yes"

    audio_output {
      type            "pipewire"
      name            "PipeWire Sound Server"
      mixer_type      "software"
    }
  '';

  # Define MPD as a native systemd User Service
  # This runs inside your user session alongside PipeWire
  systemd.user.services.mpd = {
    enable = true;
    description = "Music Player Daemon";
    wantedBy = [ "default.target" ];
    after = [ "pipewire.service" ];

    serviceConfig = {
      ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon /etc/mpd.conf";
      Restart = "on-failure";
    };

    preStart = ''
      mkdir -p /home/moonburst/.config/mpd/playlists
      mkdir -p /home/moonburst/.local/share/mpd
    '';
  };
}
