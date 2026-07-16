{ config, pkgs, lib, ... }: {
  imports = [
  #  ./sso.nix
    ./matrix.nix
   # ./fluxer.nix
  ];

  # Centralized PostgreSQL Service using Version 16
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    enableTCPIP = true;

    # Consolidates databases required by your web modules
    ensureDatabases = [
      "mautrix-discord"
      "fluxer"
    ];

    # Consolidates database service accounts
    ensureUsers = [
      { name = "mautrix-discord"; ensureDBOwnership = true; }
      { name = "fluxer"; ensureDBOwnership = true; }
    ];

    # Safe local and socket authentication configuration block
    authentication = pkgs.lib.mkForce ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';

    settings = {
      log_checkpoints = false;
      log_min_messages = "error";
    };
  };

  # Centralized Nginx HTTP reverse-proxy engine
  services.nginx = {
    enable = true;
  };
}
