{ config, pkgs, ... }:

{
  users.users.matrix-synapse.extraGroups = [ "mautrix-discord" ];

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
      log_min_error_statement = "error";
    };
  };

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [
      config.sops.secrets.matrix_macaroon_secret.path
      config.sops.secrets.matrix_registration_secret.path
    ];

    # Silences Synapse info/debug spam and specific federation 401 errors
    log = {
      root.level = "WARNING";
      loggers = {
        "synapse.access.http.8008".level = "WARNING";
        "synapse.storage.SQL".level = "WARNING";

        # Target the specific modules responsible for the federation retry spam
        "synapse.http.matrixfederationclient".level = "ERROR";
        "synapse.federation.sender".level = "ERROR";
        "synapse.http.client".level = "ERROR";
      };
    };

    settings = {
      server_name = "moonburst.net";
      public_baseurl = "https://moonburst.net";
      registration_shared_secret = config.sops.secrets.matrix_registration_secret.path;

      database = {
        name = "psycopg2";
        allow_unsafe_locale = true;
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
        };
      };

      listeners = [
        {
          port = 8008;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [ { names = [ "client" "federation" ]; compress = false; } ];
        }
      ];
    };
  };

  services.mautrix-discord = {
    enable = true;
    registerToSynapse = true;

    settings = {
      # This block silences the Go-based mautrix-discord bridge
      logging = {
        min_level = "error";
        writers = [
          {
            type = "stdout";
            format = "pretty-colored";
            level = "error";
          }
        ];
      };

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
        permissions = {
          "@moonburst:moonburst.net" = "admin";
        };
        direct_media = true;

        media_viewer = {
          enabled = true;
          template = "https://moonburst.net{{.ID}}";
        };
      };
    };
  };

  systemd.services.mautrix-discord.after = [ "matrix-synapse.service" ];
}
