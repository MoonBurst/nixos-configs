{ config, pkgs, lib, ... }:

let
  musicDomain = "music.moonburst.net";
in
{
  services.navidrome = {
    enable = true;
    settings = {
      Address = "0.0.0.0";
      Port = 4533;
      MusicFolder = "/home/moonburst/Music";
      LogLevel = "INFO";
      DefaultTheme = "Dark";
      EnableCoverAnimation = true;
      EnableTranscodingConfig = true;
      EnableSharing = true;

      ReverseProxyUserHeader = "Remote-User";
      ReverseProxyWhitelist = "0.0.0.0/0, ::/0, 127.0.0.1/32, ::1/128";
      "ExtAuth.UserHeader" = "Remote-User";
      "ExtAuth.TrustedSources" = "0.0.0.0/0, ::/0, 127.0.0.1/32, ::1/128";
    };
  };

  systemd.services.navidrome.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "moonburst";
    Group = lib.mkForce "users";
    ProtectHome = lib.mkForce false;
    ProtectSystem = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
  };

  systemd.tmpfiles.rules = [
    "Z /var/lib/navidrome 0755 moonburst users -"
  ];

  services.nginx.virtualHosts."${musicDomain}" = {
    listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:4533";
      # Note: No duplicate Host header here!
      extraConfig = ''
        proxy_set_header Remote-User "guest";
        add_header X-Robots-Tag "noindex, nofollow, noarchive" always;
      '';
    };
  };
}
