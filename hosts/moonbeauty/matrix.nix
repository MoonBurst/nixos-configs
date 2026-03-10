{ config, pkgs, lib, ... }:

{
  # 1. Secret Definitions
  sops.secrets = {
    "cloudflare_token" = { };
    "matrix_macaroon_secret" = { owner = "matrix-synapse"; };
    "matrix_registration_secret" = { owner = "matrix-synapse"; };
  };

  # 2. Cloudflare Tunnel
  users.users.cloudflared = { isSystemUser = true; group = "cloudflared"; };
  users.groups.cloudflared = {};

  systemd.services.cloudflared-tunnel = {
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wants = [ "network-online.target" "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Restart = "always";
      RestartSec = "5";
      User = "cloudflared";
      Group = "cloudflared";
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
      LogLevelMax = "warning";
    };

    script = lib.mkForce ''
      ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run > /dev/null
    '';
  };

  # 3. Nginx Gateway
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    commonHttpConfig = ''
      proxy_buffer_size 128k;
      proxy_buffers 4 256k;
      proxy_busy_buffers_size 256k;
      access_log off;
      error_log stderr warn;
    '';

    virtualHosts."moonburst.net" = {
      default = true;
      serverName = "moonburst.net";
      serverAliases = [ "localhost" "127.0.0.1" ];
      addSSL = false;

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

      locations."/" = {
        proxyPass = "http://127.0.0.1:8008";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          client_max_body_size 100M;
        '';
      };

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
    settings = {
      log_min_messages = "warning";
      log_checkpoints = "off";
    };
  };

  # 5. Matrix Synapse
  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.secrets.matrix_macaroon_secret.path ];

    settings = {
      server_name = "moonburst.net";
      public_baseurl = "https://moonburst.net";
      registration_shared_secret_path = config.sops.secrets.matrix_registration_secret.path;
      trusted_proxies = [ "127.0.0.1" "::1" ];

      # Media and Preview Settings
      url_preview_enabled = true;
      url_preview_ip_range_allowlist = [ "0.0.0.0/0" ];
      max_upload_size = "100M";

      log_config = pkgs.writeText "synapse-log-config.json" (builtins.toJSON {
        version = 1;
        formatters.precise.format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s";
        handlers.console = {
          class = "logging.StreamHandler";
          formatter = "precise";
        };
        loggers = {
          "synapse.http.matrixfederationclient" = { level = "ERROR"; };
          "synapse.federation.sender" = { level = "ERROR"; };
          "synapse.media.media_repository" = { level = "ERROR"; };
          "synapse.http.server" = { level = "ERROR"; };
          "synapse.federation.transport.server._base" = { level = "ERROR"; };
          "synapse.federation.transport.server" = { level = "ERROR"; };
          "synapse.crypto.keyring" = { level = "ERROR"; };
        };
        root = {
          level = "WARNING";
          handlers = [ "console" ];
        };
      });

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
      bridge = {
        permissions = { "@moonburst:moonburst.net" = "admin"; };
        direct_media = false; # Fixes visibility for Discord CDN links
                # Tells the bridge to treat Tenor/Giphy MP4s as images
        animated_sticker = { target = "gif"; };
        # Forces Discord's "external" media to be re-uploaded locally
        provisioning_api = true;
      };
      logging.level = "warn";
    };
  };

  # 7. Systemd Tweaks & Output Filtering
  systemd.services.mautrix-discord.after = [ "matrix-synapse.service" ];
  systemd.services.mautrix-discord.serviceConfig.LogLevelMax = "warning";

  systemd.services.matrix-synapse = {
    serviceConfig.LogLevelMax = "warning";
    serviceConfig.ExecStartPre = lib.mkForce [ ];
  };

  users.users.matrix-synapse.extraGroups = [ "mautrix-discord" ];
}
