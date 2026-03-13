{ config, pkgs, lib, ... }:

{
  ##############################################################################
  # KERNEL EDIT  # Hopefully fixes audio stuttering
  ##############################################################################
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };

  ##############################################################################
  # LOGGING & SECURITY (SILENCE THE NOISE)
  ##############################################################################
  systemd.settings.Manager.LogLevel = "warning";



  ##############################################################################
  # SECRETS & PERMISSIONS
  ##############################################################################
  sops.secrets = {
    "cloudflare_token" = { };
    "matrix_macaroon_secret" = { owner = "matrix-synapse"; };
    "matrix_registration_secret" = { owner = "matrix-synapse"; };
  };

  users.users.matrix-synapse.extraGroups = [ "mautrix-discord" "postgres" ];
  users.users.mautrix-discord.extraGroups = [ "postgres" ];

  ##############################################################################
  # NETWORK GATEWAY (Cloudflare & Nginx)
  ##############################################################################
  systemd.services.cloudflared-tunnel = {
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wants = [ "network-online.target" "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "5";
      DynamicUser = true;
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
    };
    script = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --proxy-connect-timeout 300s";
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."moonburst.net" = {
      default = true;
      locations = {
        "= /.well-known/matrix/server".extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.server":"moonburst.net:443"}';
        '';
        "= /.well-known/matrix/client".extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{
            "m.homeserver": {"base_url":"https://moonburst.net"},
            "org.matrix.msc4143.rtc_foci": [
              {
                "type": "livekit",
                "livekit_service_url": "https://livekit-jwt.call.matrix.org"
              }
            ]
          }';
        '';
        "/" = {
          proxyPass = "http://127.0.0.1:8008";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
            proxy_connect_timeout 300s;
          '';
        };

        "= /".extraConfig = ''
          add_header Content-Type text/plain;
          return 200 'Moonburst Matrix Server Active';
        '';
      };
    };
  };


  ##############################################################################
  # DATABASE (PostgreSQL)
  ##############################################################################
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "matrix-synapse" "mautrix-discord" ];
    ensureUsers = [
      { name = "matrix-synapse"; ensureDBOwnership = true; }
      { name = "mautrix-discord"; ensureDBOwnership = true; }
    ];
    settings = {
      log_checkpoints = false;
      log_min_messages = "warning";
      random_page_cost = 1.1;
      effective_cache_size = "4GB";
    };
  };

  ##############################################################################
  # MATRIX HOMESERVER (Synapse)
  ##############################################################################
  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.secrets.matrix_macaroon_secret.path ];
    settings = {
      server_name = "moonburst.net";
      public_baseurl = "https://moonburst.net";
      enable_registration = true;
      enable_registration_without_verification = true;
      suppress_key_server_warning = true;
      registration_shared_secret_path = config.sops.secrets.matrix_registration_secret.path;
      trusted_proxies = [ "127.0.0.1" "::1" ];
      url_preview_enabled = true;
      url_preview_ip_range_allowlist = [ "0.0.0.0/0" ];
      max_upload_size = "100M";

      federation_sender_instances = [ "main" ];
      background_processes_parallelism_limit = 10;
      media_retention_days = 7;

      database = {
        name = "psycopg2";
        allow_unsafe_locale = true;
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
        };
      };

      log_config = pkgs.writeText "synapse-log-config.json" (builtins.toJSON {
        version = 1;
        formatters.precise.format = "%(asctime)s - %(name)s - %(levelname)s - %(message)s";
        handlers.console = { class = "logging.StreamHandler"; formatter = "precise"; };
        root = { level = "WARNING"; handlers = [ "console" ]; };
      });
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

  ##############################################################################
  # DISCORD BRIDGE (Mautrix-Discord)
  ##############################################################################
  services.mautrix-discord = {
    enable = true;
    registerToSynapse = true;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:8008";
        domain = "moonburst.net";
      };
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
        animated_sticker.target = "gif";
        provisioning_api = true;
      };
      logging.level = "warn";
    };
  };

  ##############################################################################
  # SERVICE TWEAKS
  ##############################################################################
  systemd.services.matrix-synapse.serviceConfig = {
    CPUWeight = 200;
    IOWeight = 200;
    CPUAffinity = "0 1";
  };
  systemd.services.postgresql.serviceConfig.CPUAffinity = "0 1";
  systemd.services.cloudflared-tunnel.serviceConfig.CPUAffinity = "0 1";

  systemd.services.nginx.serviceConfig.Restart = "always";

  systemd.services.mautrix-discord = {
    after = [ "matrix-synapse.service" "postgresql.service" ];
    serviceConfig.StateDirectory = "mautrix-discord";
    serviceConfig.CPUAffinity = "0 1";
  };
}
