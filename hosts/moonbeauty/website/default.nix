{ config, pkgs, lib, ... }: {
  imports = [
    ./matrix.nix
    ./navidrome.nix
    ./microbin.nix
    ./share-approver.nix
    ./audiobookshelf.nix
    ./authentik.nix
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    enableTCPIP = true;

    ensureDatabases = [
      "mautrix-discord"
      "authentik"
    ];

    ensureUsers = [
      { name = "mautrix-discord"; ensureDBOwnership = true; }
      { name = "authentik"; ensureDBOwnership = true; }
    ];

    authentication = pkgs.lib.mkForce ''
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';

    settings = {
      log_checkpoints = false;
      log_min_messages = "error";
    };
  };

  services.nginx = {
    enable = true;
    clientMaxBodySize = "10G";
    recommendedProxySettings = true;

    # Fix the proxy_headers_hash warning & buffer size
    commonHttpConfig = ''
      proxy_headers_hash_max_size 1024;
      proxy_headers_hash_bucket_size 128;
      add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    '';
  };
}
