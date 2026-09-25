{ config, pkgs, lib, ... }: {
  services.audiobookshelf = {
    enable = true;
    host = "127.0.0.1";
    port = 8000;
  };

  # Allow audiobookshelf user to access group-owned files
  systemd.services.audiobookshelf.serviceConfig = {
    SupplementaryGroups = [ "users" ];
  };

  services.nginx.virtualHosts."audiobooks.moonburst.net" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.audiobookshelf.port}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
      '';
    };
  };
}
