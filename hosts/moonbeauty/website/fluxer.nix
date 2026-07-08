{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nodejs
    pnpm
    rustc
    cargo
    wasm-pack
    erlang
    openssl
    pkg-config
    cacert
    gcc
    lld
    clang
    git
  ];

  users.users.fluxer = {
    isSystemUser = true;
    group = "fluxer";
    home = "/srv/fluxer";
    createHome = true;
  };
  users.groups.fluxer = {};

  systemd.tmpfiles.rules = [
    "d /srv/fluxer 0775 fluxer users -"
  ];

  services.redis.servers.fluxer = {
    enable = true;
    port = 6379;
    bind = "127.0.0.1";
  };

  services.meilisearch = {
    enable = true;
    listenAddress = "127.0.0.1";
    listenPort = 7700;
    masterKeyFile = pkgs.writeText "meili-key" "your_meili_master_hex_key_here";
  };

  services.nats = {
    enable = true;
    port = 4222;
    jetstream = true;
  };

  systemd.services.livekit = {
    description = "LiveKit Voice/Video Signaling Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.livekit}/bin/livekit-server --config /srv/fluxer/config/livekit.yaml";
      Restart = "always";
      LimitNOFILE = 65535;
    };
  };

  systemd.services.fluxer = {
    description = "Fluxer Monolith Server Daemon";
    after = [ "network.target" "redis-fluxer.service" "meilisearch.service" "nats.service" "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    path = with pkgs; [ 
      nodejs 
      pnpm 
      erlang 
      git 
      cacert 
      rustc 
      cargo 
      wasm-pack 
      gcc 
      lld
      clang
      pkg-config 
      openssl 
      bash
      coreutils
    ];

    preStart = ''
      export GIT_SSL_CAINFO="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      mkdir -p /srv/fluxer/config

      if [ ! -d "/srv/fluxer/fluxer" ]; then
        echo "=== Cloned repository missing. Starting automatic git clone... ==="
        cd /srv/fluxer
        git clone https://github.com/fluxerapp/fluxer.git
        cd fluxer
        pnpm install
        cd fluxer_app
        pnpm lingui:compile
        pnpm build
        cd ..
      fi
    '';

    serviceConfig = {
      Type = "simple";
      User = "fluxer";
      Group = "fluxer";
      WorkingDirectory = "/srv/fluxer/fluxer";
      ExecStart = "${pkgs.pnpm}/bin/pnpm --filter fluxer_api start";
      Restart = "always";

      Environment = [
        "FLUXER_CONFIG=/srv/fluxer/config/config.json"
        "FLUXER_BASE_DOMAIN=fluxer.moonburst.net"
        "FLUXER_DATABASE_BACKEND=postgres"
        "FLUXER_POSTGRES_HOST=127.0.0.1"
        "FLUXER_POSTGRES_PORT=5432"
        "FLUXER_POSTGRES_DATABASE=fluxer"
        "FLUXER_POSTGRES_USERNAME=fluxer"
        "NODE_ENV=production"
        "FLUXER_PUBLIC_SCHEME=https"
        "FLUXER_ENV=production"
        "FLUXER_SUDO_MODE_SECRET=5c5d808cf7429188d8b9d31154625b5ea82d4999ab1d19853920c74d812fe86c"
        "FLUXER_ADMIN_SECRET_KEY_BASE=7b34e56fa2d19bc0ea8c89b3310da48b48de9cbf670d6eb8479e0a84e318cf01"
      ];

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/srv/fluxer" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 7881 ];
    allowedUDPPorts = [ 3478 ];
    allowedUDPPortRanges = [ { from = 50000; to = 50100; } ];
  };

  services.nginx.virtualHosts = {
    "fluxer.moonburst.net" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
        '';
      };
    };

    "lk.moonburst.net" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:7880";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
        '';
      };
    };
  };
}
