{ config, pkgs, lib, ... }:

let
  registrationPath = config.sops.templates."discord-registration.yaml".path;
  puppetSecretPath = config.sops.secrets.matrix_double_puppet_secret.path;

  element-web-config = pkgs.writeTextDir "config.json" (builtins.toJSON {
    default_server_config = {
      "m.homeserver" = { "base_url" = "https://moonburst.net"; "server_name" = "moonburst.net"; };
    };
    "element_call" = { "url" = "https://call.element.io"; "use_excalidraw" = true; };
    "features" = { "feature_group_calls" = true; "feature_video_rooms" = true; };
    disable_custom_urls = true;
    disable_guests = true;
    show_labs_settings = true;
  });
in
{
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  sops.secrets = {
    "cloudflare_token" = { };
    "moonburst_password" = { neededForUsers = true; };
    "matrix_macaroon_secret" = { owner = lib.mkForce "continuwuity"; };
    "matrix_registration_secret" = { owner = lib.mkForce "continuwuity"; };
    "discord_bot_token" = { owner = lib.mkForce "mautrix-discord"; };
    "matrix_as_token" = { };
    "matrix_hs_token" = { };
    "matrix_double_puppet_secret" = { owner = lib.mkForce "continuwuity"; };
  };

  sops.templates."discord-registration.yaml" = {
    content = ''
      id: discord-bridge
      as_token: ${config.sops.placeholder.matrix_as_token}
      hs_token: ${config.sops.placeholder.matrix_hs_token}
      namespaces:
        users: [{ exclusive: true, regex: "@discord_.*:moonburst.net" }]
        aliases: [{ exclusive: true, regex: "#discord_.*:moonburst.net" }]
      url: "http://127.0.0.1:29334"
      sender_localpart: discordbot
      rate_limited: false
    '';
    owner = "continuwuity";
  };

  services.matrix-continuwuity = {
    enable = true;
    settings.global = {
      server_name = "moonburst.net";
      port = [ 6167 ];
      address = [ "127.0.0.1" ];
      allow_registration = false;
      appservice_files = [ "${registrationPath}" ];
      registration_token_file = config.sops.secrets.matrix_registration_secret.path;
      login_shared_secret_file = puppetSecretPath;
    };
  };

  systemd.services.continuwuity.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "continuwuity";
    Group = "continuwuity";
    ReadWritePaths = [ "/var/lib/continuwuity" ];
  };

  services.mautrix-discord = {
    enable = true;
    registerToSynapse = false;
    environmentFile = config.sops.secrets.discord_bot_token.path;
    settings = {
      homeserver = {
        address = "http://127.0.0.1:6167";
        domain = "moonburst.net";
      };
      appservice = {
        id = "discord-bridge";
        address = "http://127.0.0.1:29334";
        port = 29334;
        database = {
          type = "postgres";
          uri = "postgres:///mautrix-discord?host=/run/postgresql";
        };
        bot = {
          username = "discordbot";
          displayname = "Discord Bridge";
          avatar = "mxc://moonburst.net/jYh24wk9b4PV2tuCG66l4tMJoumb0tZj";
        };
      };
      bridge = {
        username_template = "discord_{{.}}";
        # FIX: Pulls proper casing from Discord
        displayname_template = "\${displayname}";

        # AUTO-OPEN DMs (ONLY NEW ONES)
        invitation_strategy = "join";
        # Set to 0 to prevent grabbing all old DMs on startup
        startup_private_channel_create_limit = 0;

        # PROFILE SYNC: Fixes the generic icon and lowercase name
        sync_with_custom_puppets = true;
        sync_direct_chat_list = false; # Set to false to prevent grabbing old DMs
        update_direct_chat_metadata = true;
        double_puppet_allow_discovery = true;

        double_puppet_server_map = {
          "moonburst.net" = "http://127.0.0.1:6167";
        };
        login_shared_secret_file = {
          "moonburst.net" = puppetSecretPath;
        };

        permissions = {
          "moonburst.net" = "user";
          "@moonburst:moonburst.net" = "admin";
        };
      };
    };
  };

  systemd.services.mautrix-discord.serviceConfig.SupplementaryGroups = [ "continuwuity" ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "mautrix-discord" ];
    ensureUsers = [{ name = "mautrix-discord"; ensureDBOwnership = true; }];
  };

  services.nginx = {
    enable = true;
    virtualHosts."moonburst.net" = {
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
        "/_matrix" = {
          proxyPass = "http://127.0.0.1:6167";
          proxyWebsockets = true;
        };
        "= /config.json".alias = "${element-web-config}/config.json";
        "/" = {
          root = pkgs.element-web;
          index = "index.html";
        };
      };
    };
  };

  systemd.services.cloudflared-tunnel = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run";
      Restart = "always";
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
  ];
}
