{ config, pkgs, lib, ... }: {
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  services.redis.servers."authentik" = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  virtualisation.oci-containers.containers = {
    authentik-server = {
      image = "ghcr.io/goauthentik/server:2024.12.3";
      cmd = [ "server" ];
      environment = {
        AUTHENTIK_REDIS__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_LISTEN__HTTP = "127.0.0.1:9000";
        AUTHENTIK_HOST = "https://auth.moonburst.net";
      };
      environmentFiles = [ "/var/lib/authentik/authentik.env" ];
      volumes = [
        "/var/lib/authentik/media:/media"
        "/var/lib/authentik/custom-templates:/templates"
      ];
      extraOptions = [ "--network=host" ];
    };

    authentik-worker = {
      image = "ghcr.io/goauthentik/server:2024.12.3";
      cmd = [ "worker" ];
      environment = {
        AUTHENTIK_REDIS__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__HOST = "127.0.0.1";
        AUTHENTIK_POSTGRESQL__NAME = "authentik";
        AUTHENTIK_POSTGRESQL__USER = "authentik";
        AUTHENTIK_HOST = "https://auth.moonburst.net";
      };
      environmentFiles = [ "/var/lib/authentik/authentik.env" ];
      volumes = [
        "/var/lib/authentik/media:/media"
        "/var/lib/authentik/custom-templates:/templates"
      ];
      extraOptions = [ "--network=host" ];
    };
  };

  services.nginx.virtualHosts."auth.moonburst.net" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:9000";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Forwarded-Proto https;
      '';
    };
  };
}
