{ config, pkgs, lib, ... }:

{
  # 1. Secret Definitions
  sops.secrets = {
    "cloudflare_token" = { };
    "matrix_macaroon_secret" = { owner = "matrix-synapse"; };
    "matrix_registration_secret" = { owner = "matrix-synapse"; };
  };

  # 2. Cloudflare Tunnel (Ensure Dashboard points to http://localhost:80)
  users.users.cloudflared = { isSystemUser = true; group = "cloudflared"; };
  users.groups.cloudflared = {};

  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel for Matrix";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --no-tls-verify";
      Restart = "always";
      User = "cloudflared";
      Group = "cloudflared";
    };
  };

  # 3. Nginx Gateway (The "Front Door")
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    # Global buffers to prevent Cloudflare "Connectivity Lost" errors
    commonHttpConfig = ''
      proxy_buffer_size 128k;
      proxy_buffers 4 256k;
      proxy_busy_buffers_size 256k;
    '';

    virtualHosts."moonburst.net" = {
      default = true;
      serverName = "moonburst.net";
      serverAliases = [ "localhost" "127.0.0.1" ];

      # Cloudflare handles SSL; Nginx stays on Port 80
      addSSL = false;

      # DISCOVERY: Exact matches to prevent Synapse from intercepting with a 302
      locations."= /.well-known/matrix/server" = {
        priority = 1;
        extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.server":"moonburst.net:443"}';
        '';
      };

      locations."= /.well-known/matrix/client" = {
        priority = 1;
        extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.homeserver":{"base_url":"https://moonburst.net"}}';
        '';
      };

      # SYNAPSE API: Proxy everything else to 8008
      locations."/" = {
        proxyPass = "http://127.0.0.1:8008";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https; # Force Synapse to see HTTPS
          client_max_body_size 50M;
        '';
      };

      # Landing Page Override (prevents the Synapse HTML from showing on root)
      locations."= /" = {
        priority = 100;
        extraConfig = ''
          add_header Content-Type text/plain;
          return 200 'Moonburst Matrix Server Active';
        '';
      };
    };
  };

  # 4. PostgreSQL Database
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "matrix-synapse" "mautrix-discord" ];
    ensureUsers = [
      { name = "matrix-synapse"; ensureDBOwnership = true; }
      { name = "mautrix-discord"; ensureDBOwnership = true; }
    ];
  };

  # 5. Matrix Synapse Service
  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.secrets.matrix_macaroon_secret.path ];
    settings = {
      server_name = "moonburst.net";
      public_baseurl = "https://moonburst.net";
      registration_shared_secret_path = config.sops.secrets.matrix_registration_secret.path;

      # Allow Nginx/Cloudflare Tunnel to pass through real IPs
      trusted_proxies = [ "127.0.0.1" "::1" ];

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

  # 6. Discord Bridge
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

  # 7. Systemd Tweaks
  systemd.services.mautrix-discord.after = [ "matrix-synapse.service" ];
  users.users.matrix-synapse.extraGroups = [ "mautrix-discord" ];
  systemd.services.matrix-synapse.serviceConfig.ExecStartPre = lib.mkForce [ ];
}
