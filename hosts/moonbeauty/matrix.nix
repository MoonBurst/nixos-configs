{ config, pkgs, lib, ... }:

let
  registrationPath = "/run/discord-registration.yaml";
  bridgeConfigPath = "/var/lib/mautrix-discord/bridge-config.yaml";
  puppetSecretPath = config.sops.secrets.matrix_double_puppet_secret.path;
  discordEnvPath = config.sops.templates."discord-env".path;
  cinny-config = pkgs.writeText "config.json" (builtins.toJSON {
    default/*Homeserver*/ = 0;
    homeserverList = [
      "moonburst.net"
    ];
  });
in

{
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  sops.secrets = {
    "matrix_as_token" = { owner = "mautrix-discord"; };
    "matrix_hs_token" = { owner = "mautrix-discord"; };
    "discord_bot_token" = { owner = "mautrix-discord"; };
    "matrix_macaroon_secret" = { owner = "continuwuity"; };
    "matrix_registration_secret" = { owner = "continuwuity"; };
    "matrix_double_puppet_secret" = { owner = "continuwuity"; };
    "cloudflare_token" = { owner = "continuwuity"; };
  };

  sops.templates."mautrix-discord-config" = {
    path = bridgeConfigPath;
    owner = "mautrix-discord";
    content = ''
      homeserver:
        address: http://127.0.0.1:6167
        domain: moonburst.net
        verify_ssl: false
      appservice:
        address: http://127.0.0.1:29334
        port: 29334
        database:
          type: postgres
          uri: postgres:///mautrix-discord?host=/run/postgresql
        id: discord-bridge
        as_token: ${config.sops.placeholder.matrix_as_token}
        hs_token: ${config.sops.placeholder.matrix_hs_token}
        bot:
          username: discordbot
          displayname: Discord Bridge
      bridge:
        username_template: "discord_{{.}}"
        displayname_template: "{{.DisplayName}}"
        sync_with_custom_puppets: true
        get_embeds: true
        media_h_f_v: true
        disable_discord_reply_mention: false
        private_chat_portal_meta: true
        double_puppet_server_map:
          "moonburst.net": "http://127.0.0.1:6167"
        login_shared_secret_file:
          "moonburst.net": ${puppetSecretPath}
        permissions:
          "moonburst.net": "user"
          "@moonburst:moonburst.net": "admin"
      logging:
        print_level: debug
    '';
  };

  sops.templates."discord-env" = {
    owner = "mautrix-discord";
    content = "MAUTRIX_DISCORD_DISCORD_TOKEN=${config.sops.placeholder.discord_bot_token}";
  };

  sops.templates."discord-registration.yaml" = {
    path = registrationPath;
    owner = "continuwuity";
    content = ''
      id: discord-bridge
      as_token: ${config.sops.placeholder.matrix_as_token}
      hs_token: ${config.sops.placeholder.matrix_hs_token}
      namespaces:
        users:
          - exclusive: true
            regex: "@discord_.*:moonburst.net"
          - exclusive: true
            regex: "@discordbot:moonburst.net"
        aliases: [{ exclusive: true, regex: "#discord_.*:moonburst.net" }]
      url: "http://127.0.0.1:29334"
      sender_localpart: discordbot
      rate_limited: false
    '';
  };


  services.matrix-continuwuity = {
    enable = true;
    settings = {
      global = {
        server_name = "moonburst.net";
        port = [ 6167 ];
        address = [ "127.0.0.1" ];
        max_request_size = 52428800;
        allow_registration = true;
        registration_token_file = config.sops.secrets.matrix_registration_secret.path;
        login_shared_secret_file = puppetSecretPath;
        url_preview_enabled = true;
        url_preview_ip_range_blacklist = [ "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "::1/128" ];
      };
      appservice.config_files = [ registrationPath ];
    };
  };

  systemd.services.continuwuity.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "continuwuity";
    Group = "continuwuity";
    StateDirectory = "continuwuity";
    ReadWritePaths = [ "/var/lib/continuwuity" ];
    LogLevelMax = "err";
  };

  services.mautrix-discord = {
    enable = true;
    registerToSynapse = false;
    environmentFile = discordEnvPath;
    settings = {
      homeserver = { address = "http://127.0.0.1:6167"; domain = "moonburst.net"; };
      appservice.database.type = "postgres";
    };
  };

  systemd.services.mautrix-discord = {
    after = [ "postgresql.service" ];
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.mautrix-discord}/bin/mautrix-discord --config=${bridgeConfigPath}";
      SupplementaryGroups = [ "continuwuity" "postgres" ];
      LogLevelMax = "err";
    };
  };

services.postgresql = {
  enable = true;
  package = pkgs.postgresql_16;
  ensureDatabases = [ "mautrix-discord" ];
  ensureUsers = [{ name = "mautrix-discord"; ensureDBOwnership = true; }];
  settings = {
    log_checkpoints = false;
    log_min_messages = "error";
  };
};

  services.nginx = {
    enable = true;
    virtualHosts."moonburst.net" = {
      extraConfig = ''
        client_max_body_size 50M;
        access_log off;
      '';
      locations = {
        "= /.well-known/matrix/server".extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 '{"m.server":"moonburst.net:443"}';
        '';
        "= /.well-known/matrix/client".extraConfig = ''
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
          return 200 "{\"m.homeserver\":{\"base_url\":\"https://moonburst.net\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://livekit-jwt.call.matrix.org\"}]}";
        '';
        "/_matrix/media" = {
          proxyPass = "http://127.0.0.1:6167";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_buffering off;
            proxy_pass_header Authorization;
            proxy_pass_header Content-Type;
          '';
        };
        "/_matrix" = {
          proxyPass = "http://127.0.0.1:6167";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_pass_header Authorization;
            proxy_pass_header Content-Type;
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
          '';
        };

        "= /config.json".extraConfig = ''
          alias ${cinny-config};
          add_header Content-Type application/json;
          add_header Access-Control-Allow-Origin *;
        '';
        "/" = {
          proxyPass = "https://dev.cinny.in";
          proxyWebsockets = true;
        };
      };
    };
  };

systemd.services.cloudflared-tunnel = {
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    EnvironmentFile = config.sops.secrets.cloudflare_token.path;
    ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --protocol http2";
    Restart = "always";
    RestartSec = "5s";
    User = "continuwuity";
  };
};


  users.groups.continuwuity = {};
  users.users.continuwuity = {
    isSystemUser = true;
    group = "continuwuity";
    extraGroups = [ "mautrix-discord" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/mautrix-discord 0750 mautrix-discord mautrix-discord -"
    "d /var/lib/continuwuity 0700 continuwuity continuwuity -"
    "d /var/lib/continuwuity/media 0700 continuwuity continuwuity -"
  ];

}
