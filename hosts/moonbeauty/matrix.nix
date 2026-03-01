{ config, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [{
      name = "matrix-synapse";
      ensureDBOwnership = true;
    }];
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

      serve_server_wellknown = true;
      report_stats = false;

      listeners = [
        {
          port = 8008;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            { names = [ "client" "federation" ]; compress = false; }
          ];
        }
      ];
    };
  };
}
