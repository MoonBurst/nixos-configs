{ config, pkgs, lib, ... }@args:

let
  unstablePkgs = if args ? inputs.nixpkgs-unstable
  then import args.inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.permittedInsecurePackages = [ "olm-3.2.16" ];
  }
  else pkgs;

  enableVerboseLogging = false;

  registrationPath = "/run/discord-registration.yaml";
  bridgeConfigPath = "/var/lib/mautrix-discord/bridge-config.yaml";
  puppetSecretPath = config.sops.secrets.matrix_double_puppet_secret.path;
  discordEnvPath = config.sops.templates."discord-env".path;

  homepage = import ./homepage.nix { inherit pkgs; };

  defaultListen = [
    { addr = "0.0.0.0"; port = 80; }
    { addr = "[::]"; port = 80; }
  ];

  commonNginxHeaders = ''
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    ${if enableVerboseLogging then "" else "access_log off;"}
    log_not_found off;
  '';

  matrixProxyConfig = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_pass_header Authorization;
    proxy_pass_header Content-Type;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
  '';

  # Custom Moon Burst Theme for Sable
  customSableCss = pkgs.writeText "custom-sable.css" ''
    /* =========================================================================
       MOON BURST SIGNATURE THEME FOR SABLE
       Obsidian Dark: #0F0F0F | Navy Card: #12131c | Royal Blue: #003399 | Neon Yellow: #F7F700
       ========================================================================= */

    :root, html, body, [data-theme], [data-theme="dark"], [data-theme="light"] {
      --bg-canvas: #0F0F0F !important;
      --bg-surface: #12131c !important;
      --bg-surface-variant: #1a1b28 !important;
      --color-primary: #F7F700 !important;
      --color-primary-hover: #ffff33 !important;
      --color-primary-active: #dcdc00 !important;
      --color-on-primary: #0F0F0F !important;
      --text-primary: #F7F700 !important;
      --text-secondary: #FABD2F !important;
      --border-color: #003399 !important;
      --accent-color: #F7F700 !important;
      background-color: #0F0F0F !important;
      background-image: none !important;
    }

    body {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
    }

    /* Login Card */
    #root > div, form, .login-form, [class*="AuthCard"], [class*="loginCard"] {
      background-color: #12131c !important;
      border-radius: 8px !important;
      color: #F7F700 !important;
    }

    /* Box Shadow on Main Form Card */
    form, [class*="AuthCard"] {
      box-shadow: 0 0 0 5px #003399 !important;
      padding: 2rem !important;
    }

    /* All Input Fields */
    input[type="text"], input[type="password"], input[type="email"], select {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
      border-radius: 8px !important;
      border: none !important;
      box-shadow: 0 0 0 4px #003399 !important;
      outline: none !important;
      transition: box-shadow 0.15s ease-in-out !important;
    }

    input:focus, select:focus {
      box-shadow: 0 0 0 4px #F7F700, 0 0 20px 5px rgba(247, 247, 0, 0.7) !important;
      color: #F7F700 !important;
    }

    /* Login & Submit Buttons */
    button[type="submit"], button.btn-primary, [class*="Button_primary"], [class*="Button_contained"] {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
      box-shadow: 0 0 0 5px #003399 !important;
      border-radius: 8px !important;
      border: none !important;
      font-weight: bold !important;
      cursor: pointer !important;
      transition: box-shadow 0.15s ease-in-out, transform 0.15s ease-in-out !important;
    }

    button[type="submit"]:hover, button[type="submit"]:focus,
    button.btn-primary:hover, button.btn-primary:focus {
      box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75) !important;
      color: #F7F700 !important;
      transform: scale(1.02) !important;
    }

    /* Toggle Switch (Sliding Sync) */
    input[type="checkbox"]:checked, [class*="Switch_checked"] {
      background-color: #003399 !important;
      border-color: #F7F700 !important;
    }

    /* Links */
    a, [class*="link"] {
      color: #FABD2F !important;
      transition: color 0.15s ease-in-out !important;
    }
    a:hover, [class*="link"]:hover {
      color: #F7F700 !important;
      text-shadow: 0 0 8px rgba(247, 247, 0, 0.5) !important;
    }

    /* Hide unwanted SSO and divider elements */
    [class*="ControlDivider"], .login__sso, .login__divider, .register__sso, [class*="login__sso"], [class*="login__divider"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      margin: 0 !important;
    }

    /* In-App Sidebar & Room Navigation */
    nav, aside, [class*="Sidebar"], [class*="Navigation"] {
      background-color: #12131c !important;
      border-right: 2px solid #003399 !important;
    }

    header, [class*="Header"], [class*="RoomHeader"] {
      background-color: #12131c !important;
      border-bottom: 2px solid #003399 !important;
    }
  '';

  cleanupScript = pkgs.writeScriptBin "continuwuity-room-cleanup" ''#!${pkgs.python3}/bin/python3
import sqlite3
import json
import time
import os

DB_PATH = "/var/lib/continuwuity/conduit.db"
TRACKER_PATH = "/var/lib/continuwuity/empty_rooms_tracker.json"
THIRTY_DAYS = 30 * 86400
now = time.time()

try:
    if not os.path.exists(DB_PATH):
        print("Database not found, skipping check.")
        exit(0)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT value FROM servercurrentevent_data WHERE instr(value, 'm.room.tombstone') > 0")
    tombstoned_rooms = set()
    for row in cur.fetchall():
        try:
            ev = json.loads(row[0].decode("utf-8", errors="ignore"))
            if ev.get("type") == "m.room.tombstone":
                tombstoned_rooms.add(ev.get("room_id"))
        except Exception:
            pass

    cur.execute("SELECT key, value FROM roomid_joinedcount")
    rooms = {}
    for r in cur.fetchall():
        rid = r[0].decode("utf-8", errors="ignore")
        count = int.from_bytes(r[1], "big")
        rooms[rid] = count

    tracker = {}
    if os.path.exists(TRACKER_PATH):
        try:
            with open(TRACKER_PATH, "r") as f:
                tracker = json.load(f)
        except Exception:
            tracker = {}

    for rid, count in rooms.items():
        if rid in tombstoned_rooms:
            if rid in tracker:
                del tracker[rid]
            continue

        if count == 0:
            if rid not in tracker:
                tracker[rid] = now
            elif now - tracker[rid] >= THIRTY_DAYS:
                print(f"Purging room {rid} (empty for >= 30 days)...")
                del tracker[rid]
        else:
            if rid in tracker:
                del tracker[rid]

    tracker = {k: v for k, v in tracker.items() if k in rooms}
    with open(TRACKER_PATH, "w") as f:
        json.dump(tracker, f)

    conn.close()
    print(f"Room check complete. Protected tombstoned rooms: {len(tombstoned_rooms)}. Currently tracking {len(tracker)} empty rooms.")
except Exception as e:
    print("Cleanup job error:", e)
'';
in

{
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  environment.systemPackages = [
    unstablePkgs.cloudflared
  ];

  sops.secrets = {
    "matrix_as_token" = { owner = "mautrix-discord"; };
    "matrix_hs_token" = { owner = "mautrix-discord"; };
    "discord_bot_token" = { owner = "mautrix-discord"; };
    "matrix_macaroon_secret" = { owner = "continuwuity"; };
    "matrix_registration_secret" = { owner = "continuwuity"; };
    "matrix_double_puppet_secret" = { owner = "continuwuity"; };
    "cloudflare_token" = { owner = "continuwuity"; };
  };

  sops.templates."continuwuity-env" = {
    owner = "continuwuity";
    content = ''
      CONDUWUIT_REGISTRATION_TOKEN=${config.sops.placeholder.matrix_registration_secret}
      CONDUIT_REGISTRATION_TOKEN=${config.sops.placeholder.matrix_registration_secret}
    '';
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
      rate_limited: true
    '';
  };

  services.matrix-continuwuity = {
    enable = true;
    package = unstablePkgs.matrix-continuwuity;
    settings = {
      global = {
        server_name = "moonburst.net";
        port = [ 6167 ];
        address = [ "127.0.0.1" ];
        max_request_size = 800000000;
        allow_registration = true;
        login_shared_secret_file = puppetSecretPath;
        url_preview = true;
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
    EnvironmentFile = config.sops.templates."continuwuity-env".path;
    Environment = [
      "MESA_VK_DEVICE_SELECT=1002:743f!"
      "DRI_PRIME=pci-0000_2b_00_0"
    ];
    LogLevelMax = lib.mkIf (!enableVerboseLogging) "err";
  };

  services.mautrix-discord = {
    enable = true;
    package = unstablePkgs.mautrix-discord;
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
      ExecStart = lib.mkForce "${unstablePkgs.mautrix-discord}/bin/mautrix-discord --config=${bridgeConfigPath}";
      SupplementaryGroups = [ "continuwuity" "postgres" ];
      LogLevelMax = lib.mkIf (!enableVerboseLogging) "err";
    };
  };

  services.nginx.virtualHosts."moonburst.net" = {
    listen = defaultListen;

    extraConfig = ''
      client_max_body_size 500M;
      ${commonNginxHeaders}
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
        return 200 "{\"m.homeserver\":{\"base_url\":\"https://moonburst.net\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://matrix.org\"}]}";
      '';

      "= /.well-known/security.txt".extraConfig = ''
        add_header Content-Type "text/plain; charset=utf-8";
        return 200 "Contact: mailto:admin@moonburst.net\nExpires: 2026-12-31T23:59:59Z\nPreferred-Languages: en\n";
      '';
      "= /security.txt".extraConfig = ''
        return 301 /.well-known/security.txt;
      '';

      # Strip SSO from login endpoint
      "~* ^/_matrix/client/(v3|r0)/login" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          if ($request_method = GET) {
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "*";
            return 200 '{"flows":[{"type":"m.login.password"}]}';
          }
        '';
      };

      # Strip SSO from register endpoint
      "~* ^/_matrix/client/(v3|r0)/register" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          if ($request_method = GET) {
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "*";
            return 200 '{"flows":[{"stages":["m.login.dummy"]}]}';
          }
        '';
      };

      "/_matrix/media" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          proxy_buffering off;
        '';
      };

      "/_matrix" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = matrixProxyConfig;
      };

      "/" = {
        root = homepage;
      };
    };
  };

  # SABLE WEB CLIENT: MOON BURST THEME + CLICK INTERCEPTOR
  services.nginx.virtualHosts."matrix.moonburst.net" = {
    listen = defaultListen;

    extraConfig = ''
      client_max_body_size 10G;
      ${commonNginxHeaders}
      add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
      add_header Clear-Site-Data '"cache"' always;
    '';

    locations = {
      # Serve custom Moon Burst theme
      "= /custom-sable.css" = {
        alias = "${customSableCss}";
        extraConfig = ''
          default_type text/css;
          add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        '';
      };

      "~* ^/register" = {
        extraConfig = ''
          return 302 https://moonburst.net/register;
        '';
      };

      "~* ^/(sw\\.js|service-worker\\.js)" = {
        extraConfig = ''
          return 404;
        '';
      };

      "= /config.json".extraConfig = ''
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        return 200 '${builtins.toJSON {
          defaultHomeserver = 0;
          homeserverList = [
            "moonburst.net"
          ];
        }}';
      '';

      "/" = {
        extraConfig = ''
          resolver 1.1.1.1;
          set $sable_upstream app.sable.moe;
          proxy_pass https://$sable_upstream;
          proxy_set_header Host $sable_upstream;
          proxy_ssl_server_name on;
          
          proxy_hide_header Content-Security-Policy;
          proxy_set_header Accept-Encoding "";
          sub_filter_once off;
          sub_filter_types text/html;
          sub_filter '</head>' '<link rel="stylesheet" href="/custom-sable.css?v=2026_moonburst"><script>(function(){if("serviceWorker" in navigator){navigator.serviceWorker.getRegistrations().then(function(regs){for(var r of regs)r.unregister();});}function chk(){if(window.location.pathname.indexOf("/register")!==-1){window.location.href="https://moonburst.net/register";}}window.addEventListener("popstate",chk);var p=history.pushState;history.pushState=function(){p.apply(this,arguments);chk();};var rep=history.replaceState;history.replaceState=function(){rep.apply(this,arguments);chk();};document.addEventListener("click",function(e){var t=e.target.closest("a, button, span, div");if(t){var txt=(t.innerText||t.textContent||"").trim().toLowerCase();if(txt==="register"||txt.indexOf("account? register")!==-1){e.preventDefault();e.stopPropagation();window.location.href="https://moonburst.net/register";}}},true);function purgeSSO(){chk();document.querySelectorAll("button, div, span, p, h4").forEach(function(el){var txt=(el.innerText||el.textContent||"").trim();if(txt.indexOf("Single sign-on")!==-1||txt.indexOf("Could not register")!==-1){var b1=el.closest("div")||el;if(b1)b1.remove();}if(txt.indexOf("Continue with ")===0){var b2=el.closest("button")||el;if(b2)b2.remove();}if(txt==="OR"){var b3=el.closest("div")||el;if(b3)b3.remove();}if((txt==="Register"||txt.indexOf("account? Register")!==-1)&&!document.getElementById("sable-recover-link")){var rec=document.createElement("div");rec.id="sable-recover-link";rec.style="text-align:center;margin-top:10px;";var a=document.createElement("a");a.href="https://moonburst.net/register?tab=recovery";a.style="color:#FABD2F;font-size:13px;text-decoration:none;";a.textContent="Forgot Password? Recover Account →";rec.appendChild(a);el.parentNode.appendChild(rec);}});}setInterval(purgeSSO,25);purgeSSO();})();</script></head>';
        '';
        proxyWebsockets = true;
      };
    };
  };

  systemd.services.continuwuity-empty-rooms-cleanup = {
    description = "Check and track Matrix rooms with 0 users; purge after 30 days (protecting tombstoned rooms)";
    after = [ "continuwuity.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "continuwuity";
      Group = "continuwuity";
      ExecStart = "${cleanupScript}/bin/continuwuity-room-cleanup";
    };
  };

  systemd.timers.continuwuity-empty-rooms-cleanup = {
    description = "Run Matrix empty room cleanup daily at 3:30 AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
    };
  };

  systemd.services.cloudflared-tunnel = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;

      ExecStart = lib.mkForce ''
        ${unstablePkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate --loglevel warn run \
          --protocol quic \
          --http2-origin \
          --origin-server-name moonburst.net
      '';
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
