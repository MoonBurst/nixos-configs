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
  };

  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [
      config.sops.secrets.matrix_macaroon_secret.path
      config.sops.secrets.matrix_registration_secret.path
    ];

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

  # ==========================================================================
  # #Discord bridge tag
  # ==========================================================================

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
