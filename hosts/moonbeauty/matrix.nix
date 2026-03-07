{ config, pkgs, lib, ... }:

{
  # 1. Secret Definitions
  sops.secrets = {
    "cloudflare_token" = { };
    "matrix_macaroon_secret" = { owner = "matrix-synapse"; };
    "matrix_registration_secret" = { owner = "matrix-synapse"; };
  };

  # 2. Cloudflare Tunnel (Fixed User/Group and SSL bypass)
  users.users.cloudflared = { isSystemUser = true; group = "cloudflared"; };
  users.groups.cloudflared = {};

  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel for Matrix";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
      # Added --no-tls-verify to fix internal certificate handshakes
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --no-tls-verify";
      Restart = "always";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };

  # 3. Nginx Gateway (Fixed Priority Routing)
  services.nginx = {
    enable = true;
    virtualHosts."moonburst.net" = {
      default = true;

      # DISCOVERY: ^~ ensures these take absolute priority over the welcome message
      locations."^~ /.well-known/matrix/server" = {
        extraConfig = ''
          default_type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.server":"moonburst.net:443"}';
        '';
      };

      locations."^~ /.well-known/matrix/client" = {
        extraConfig = ''
          default_type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.homeserver":{"base_url":"https://moonburst.net"}}';
        '';
      };

      # API ROUTES: Absolute priority for all Matrix and Admin traffic
      locations."^~ /_matrix" = {
        proxyPass = "http://127.0.0.1:8008";
        proxyWebsockets = true;
        extraConfig = ''
          add_header 'Access-Control-Allow-Origin' '*' always;
          add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
          add_header 'Access-Control-Allow-Headers' 'X-Requested-With,Content-Type,Authorization' always;
        '';
      };

      locations."^~ /_synapse/admin" = {
        proxyPass = "http://127.0.0.1:8008";
      };

      locations."= /" = {
        return = "200 'Moonburst Matrix Server Active'";
      };
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "matrix-synapse" "mautrix-discord" ];
    ensureUsers = [
      { name = "matrix-synapse"; ensureDBOwnership = true; }
      { name = "mautrix-discord"; ensureDBOwnership = true; }
    ];
  };

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.secrets.matrix_macaroon_secret.path ];
    settings = {
      server_name = "moonburst.net";
      public_baseurl = "https://moonburst.net";
      registration_shared_secret_path = config.sops.secrets.matrix_registration_secret.path;
      database = {
        name = "psycopg2";
        allow_unsafe_locale = true;
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
        };
      };
      listeners = [{
        port = 8008;
        bind_addresses = [ "127.0.0.1" ];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [ { names = [ "client" "federation" ]; compress = false; } ];
      }];
    };
  };

  services.mautrix-discord = {
    enable = true;
    registerToSynapse = true;
    settings = {
      homeserver = { address = "http://127.0.0.1:8008"; domain = "moonburst.net"; };
      appservice = {
        address = "http://127.0.0.1:29334";
        hostname = "127.0.0.1";
        port = 29334;
        database = {
          type = "postgres";
          uri = "postgres:///mautrix-discord?host=/run/postgresql";
        };
      };
      bridge = { permissions = { "@moonburst:moonburst.net" = "admin"; }; direct_media = true; };
    };
  };

  # 7. Permissions & Overrides
  systemd.services.mautrix-discord.after = [ "matrix-synapse.service" ];
  users.users.matrix-synapse.extraGroups = [ "mautrix-discord" ];
  systemd.services.matrix-synapse.serviceConfig.ExecStartPre = lib.mkForce [ ];
}
