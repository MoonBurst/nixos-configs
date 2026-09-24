{ config, pkgs, lib, ... }: {
  imports = [
    ./matrix.nix
    ./navidrome.nix
    ./microbin.nix
    ./share-approver.nix
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    enableTCPIP = true;

    ensureDatabases = [
      "mautrix-discord"
    ];

    ensureUsers = [
      { name = "mautrix-discord"; ensureDBOwnership = true; }
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

  # Set global Nginx upload capacity to 10 GB (eliminates 413 errors system-wide)
  services.nginx = {
    enable = true;
    clientMaxBodySize = "10G";
  };
}
