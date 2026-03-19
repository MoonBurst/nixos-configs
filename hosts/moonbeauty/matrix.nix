{ config, pkgs, lib, ... }:

let
  conduit-pkg = pkgs.matrix-continuwuity;

  element-web-config = pkgs.writeTextDir "config.json" (builtins.toJSON {
    default_server_config = {
      "m.homeserver" = {
        "base_url" = "https://moonburst.net";
        "server_name" = "moonburst.net";
      };
    };
    "element_call" = {
      "url" = "https://call.element.io";
      "use_excalidraw" = true;
    };
    "features" = {
      "feature_group_calls" = true;
      "feature_video_rooms" = true;
    };
    disable_custom_urls = true;
    disable_guests = true;
    show_labs_settings = true;
  });
in
{
  boot.kernel.sysctl = {
    "net.core.rmem_max" = 7500000;
    "net.core.wmem_max" = 7500000;
  };

  systemd.settings.Manager.LogLevel = "warning";

  sops = {
    defaultSopsFile = lib.mkForce ../../secrets.yaml;
    secrets = {
      "cloudflare_token" = { };
      "matrix_macaroon_secret" = { owner = lib.mkForce "matrix-conduit"; };
      "matrix_registration_secret" = { owner = lib.mkForce "matrix-conduit"; };
      "discord_bot_token" = { owner = lib.mkForce "mautrix-discord"; };
    };
  };

  users.users.matrix-conduit = {
    isSystemUser = true;
    group = "matrix-conduit";
    extraGroups = [ "mautrix-discord" "postgres" ];
  };
  users.groups.matrix-conduit = { };

  users.users.mautrix-discord = {
    isSystemUser = true;
    group = "mautrix-discord";
    extraGroups = [ "postgres" ];
  };
  users.groups.mautrix-discord = { };

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
          return 200 '{"m.homeserver":{"base_url":"https://moonburst.net"}}';
        '';
        "/_matrix" = {
          proxyPass = "http://127.0.0.1:6167";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_set_header Host "moonburst.net";
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_read_timeout 3600s;
            client_max_body_size 100M;
          '';
        };
        "= /config.json".extraConfig = "alias ${element-web-config}/config.json;";
        "/" = {
          root = pkgs.element-web;
          index = "index.html";
        };
      };
    };
  };

  systemd.services.cloudflared-tunnel = {
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wants = [ "network-online.target" "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "5";
      User = "root";
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
    };
    script = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "mautrix-discord" ];
    ensureUsers = [ { name = "mautrix-discord"; ensureDBOwnership = true; } ];
  };

  services.matrix-conduit = {
    enable = true;
    package = conduit-pkg;
    settings.global = {
      server_name = "moonburst.net";
      allow_registration = true;
      port = 6167;
      address = "127.0.0.1";
      max_request_size = 104857600;
      trusted_servers = [ "matrix.org" "moonburst.net" ];
      appservice_configs = [ "/var/lib/mautrix-discord/discord-registration.yaml" ];
    };
  };

  systemd.services.conduit.serviceConfig.ExecStart = lib.mkForce "${conduit-pkg}/bin/conduwuit";

  services.mautrix-discord = {
    enable = true;
    environmentFile = config.sops.secrets.discord_bot_token.path;
    settings = lib.mkForce {
      homeserver = {
        address = "http://127.0.0.1:6167";
        domain = "moonburst.net";
      };
      appservice = {
        address = "http://127.0.0.1:29334";
        port = 29334;
        sender_localpart = "discordbot";
        database = {
          type = "postgres";
          uri = "postgres:///mautrix-discord?host=/run/postgresql";
        };
      };
      bridge = {
        username_template = "discord_''${''}{''.ID''}${''}";
        displayname_template = "''${''}{''.DisplayName''}${''}";
        portal_only_on_message = true;
        permissions = {
          "@moonburst:moonburst.net" = "admin";
          "moonburst.net" = "user";
        };
      };
    };
  };

  system.activationScripts.mautrix-discord-config-fix.text = ''
    mkdir -p /var/lib/mautrix-discord
    cat <<EOF > /var/lib/mautrix-discord/config.yaml
homeserver:
  address: http://127.0.0.1:6167
  domain: moonburst.net
appservice:
  address: http://127.0.0.1:29334
  database:
    type: postgres
    uri: postgres:///mautrix-discord?host=/run/postgresql
  id: discord
  bot:
    username: discordbot
bridge:
  username_template: discord_{{.ID}}
  displayname_template: "{{.DisplayName}}"
  portal_only_on_message: true
  permissions:
    "@moonburst:moonburst.net": admin
    "moonburst.net": user
EOF
    chown mautrix-discord:mautrix-discord /var/lib/mautrix-discord/config.yaml
    chmod 640 /var/lib/mautrix-discord/config.yaml
  '';
}
