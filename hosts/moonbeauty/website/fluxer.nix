{ config, pkgs, ... }:

let
  baseDomain = "fluxer.moonburst.net";
in
{
  # 1. Open Firewall Ports for LiveKit Multiplexed Audio/Video
  networking.firewall.allowedTCPPorts = [ 7881 ];
  networking.firewall.allowedUDPPorts = [ 7882 ];

  # 2. Enable Podman and its local Docker socket compatibility
  virtualisation.podman = {
    enable = true;
    dockerSocket.enable = true; # Exposes the podman socket at /run/podman/podman.sock
    dockerCompat = true;       # Emulates the 'docker' command using podman
  };

  # Define sops-nix secrets mapping
  sops.secrets = {
    fluxer_postgres_password = { };
    fluxer_meili_master_key = { };
    fluxer_s3_secret_key = { };
    fluxer_sudo_mode_secret = { };
    fluxer_connection_initiation_secret = { };
    fluxer_gateway_rpc_auth_token = { };
    fluxer_media_proxy_secret_key = { };
    fluxer_media_proxy_upload_relay_secret_base64 = { };
    fluxer_admin_secret_key_base = { };
    fluxer_admin_oauth_client_secret = { };
    fluxer_vapid_public_key = { };
    fluxer_vapid_private_key = { };
    fluxer_livekit_api_secret = { };
  };

  # 3. Configuration Generation and File Patching Service
  systemd.services.fluxer-config-prep = {
    description = "Generate decrypted Fluxer env and patch ports in docker-compose";
    requiredBy = [ "fluxer-stack.service" ];
    before = [ "fluxer-stack.service" ];
    after = [ "sops-install-secrets.service" ];
    path = [ pkgs.git pkgs.gnused ]; # Ensure git and sed are available to the service

    # Provide the HOME environment variable so Git can find /root/.gitconfig
    environment = {
      HOME = "/root";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Ensure working directory exists
      mkdir -p /srv/fluxer/fluxer/deploy/self-hosting

      cd /srv/fluxer/fluxer

      # Safely replace all duplicate Git safe.directory entries to prevent overwrite errors
      git config --global --replace-all safe.directory /srv/fluxer/fluxer

      # A. Revert any previous local edits to docker-compose.yml to ensure a clean slate
      git checkout -- deploy/self-hosting/docker-compose.yml

      # B. Generate a fresh override file to inject the rate-limit and autoban bypasses
      cat << 'EOF_OVERRIDE' > deploy/self-hosting/docker-compose.override.yml
      version: '3'
      services:
        api:
          environment:
            - FLUXER_DISABLE_RATE_LIMITS=true
            - FLUXER_ABUSE_THRESHOLD_DATACENTER=999999
            - FLUXER_ABUSE_THRESHOLD_ANONYMOUS=999999
            - FLUXER_ABUSE_THRESHOLD_MOBILE=999999
            - FLUXER_ABUSE_THRESHOLD_RESIDENTIAL=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_DATACENTER=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_ANONYMOUS=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_MOBILE=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_RESIDENTIAL=999999
        worker:
          environment:
            - FLUXER_DISABLE_RATE_LIMITS=true
            - FLUXER_ABUSE_THRESHOLD_DATACENTER=999999
            - FLUXER_ABUSE_THRESHOLD_ANONYMOUS=999999
            - FLUXER_ABUSE_THRESHOLD_MOBILE=999999
            - FLUXER_ABUSE_THRESHOLD_RESIDENTIAL=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_DATACENTER=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_ANONYMOUS=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_MOBILE=999999
            - FLUXER_ABUSE_TOKEN_DIVERSITY_RESIDENTIAL=999999
        gateway:
          environment:
            - FLUXER_DISABLE_RATE_LIMITS=true
      EOF_OVERRIDE
      chmod 644 deploy/self-hosting/docker-compose.override.yml

      # C. Patch Caddy ports directly in the base docker-compose.yml file
      sed -i 's/- "80:80"/- "127.0.0.1:8085:80"/g' deploy/self-hosting/docker-compose.yml
      sed -i '/- "443:443"/d' deploy/self-hosting/docker-compose.yml

      # D. Generate the .env file using decrypted secrets
      cat << EOF > deploy/self-hosting/.env
      FLUXER_DOMAIN=${baseDomain}
      FLUXER_PUBLIC_SCHEME=https
      FLUXER_PUBLIC_PORT=443
      FLUXER_CADDY_SITE_ADDRESS=http://${baseDomain}

      FLUXER_REGISTRY_OWNER=fluxerapp
      FLUXER_REGISTRY=ghcr.io/fluxerapp
      FLUXER_IMAGE_TAG=v1

      POSTGRES_PASSWORD=$(cat ${config.sops.secrets.fluxer_postgres_password.path})
      MEILI_MASTER_KEY=$(cat ${config.sops.secrets.fluxer_meili_master_key.path})
      FLUXER_S3_ACCESS_KEY=fluxer
      FLUXER_S3_SECRET_KEY=$(cat ${config.sops.secrets.fluxer_s3_secret_key.path})

      FLUXER_SUDO_MODE_SECRET=$(cat ${config.sops.secrets.fluxer_sudo_mode_secret.path})
      FLUXER_CONNECTION_INITIATION_SECRET=$(cat ${config.sops.secrets.fluxer_connection_initiation_secret.path})
      FLUXER_GATEWAY_RPC_AUTH_TOKEN=$(cat ${config.sops.secrets.fluxer_gateway_rpc_auth_token.path})
      FLUXER_MEDIA_PROXY_SECRET_KEY=$(cat ${config.sops.secrets.fluxer_media_proxy_secret_key.path})
      FLUXER_MEDIA_PROXY_UPLOAD_RELAY_SECRET_BASE64=$(cat ${config.sops.secrets.fluxer_media_proxy_upload_relay_secret_base64.path})
      FLUXER_ADMIN_SECRET_KEY_BASE=$(cat ${config.sops.secrets.fluxer_admin_secret_key_base.path})
      FLUXER_ADMIN_OAUTH_CLIENT_SECRET=$(cat ${config.sops.secrets.fluxer_admin_oauth_client_secret.path})

      FLUXER_VAPID_PUBLIC_KEY=$(cat ${config.sops.secrets.fluxer_vapid_public_key.path})
      FLUXER_VAPID_PRIVATE_KEY=$(cat ${config.sops.secrets.fluxer_vapid_private_key.path})
      FLUXER_VAPID_EMAIL=admin@${baseDomain}

      LIVEKIT_API_KEY=fluxer
      LIVEKIT_API_SECRET=$(cat ${config.sops.secrets.fluxer_livekit_api_secret.path})

      FLUXER_KLIPY_API_KEY=

      FLUXER_EMAIL_ENABLED=false
      FLUXER_EMAIL_PROVIDER=none
      FLUXER_EMAIL_FROM_EMAIL=noreply@${baseDomain}
      FLUXER_EMAIL_FROM_NAME=Fluxer
      FLUXER_EMAIL_SMTP_HOST=
      FLUXER_EMAIL_SMTP_PORT=587
      FLUXER_EMAIL_SMTP_USERNAME=
      FLUXER_EMAIL_SMTP_PASSWORD=
      FLUXER_EMAIL_SMTP_SECURE=true

      FLUXER_CAPTCHA_ENABLED=false
      FLUXER_CAPTCHA_PROVIDER=none
      FLUXER_DISCOVERY_ENABLED=true
      FLUXER_DISABLE_RATE_LIMITS=true
      EOF
      chmod 600 deploy/self-hosting/.env
    '';
  };

  # 4. Standard Docker Compose Service on top of Podman
  systemd.services.fluxer-stack = {
    description = "Fluxer Docker Compose Stack (via Podman)";
    after = [ "network.target" "podman.socket" ];
    requires = [ "podman.socket" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker-compose pkgs.podman ];

    environment = {
      DOCKER_HOST = "unix:///run/podman/podman.sock";
    };

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/srv/fluxer/fluxer/deploy/self-hosting";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      Restart = "always";
    };
  };

  # 5. Host Nginx Setup with Header Alteration Map
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Global HTTP configuration mapping to append 'unsafe-eval' to the incoming CSP header.
    commonHttpConfig = ''
      map $upstream_http_content_security_policy $altered_csp {
          ~*^(.*script-src\s)(.*)$ "$1'unsafe-eval' $2";
          default $upstream_http_content_security_policy;
      }
    '';

    virtualHosts."${baseDomain}" = {
      # Disable Let's Encrypt / local SSL for this subdomain
      # because SSL is terminated cleanly by Cloudflare's edge.
      addSSL = false;
      forceSSL = false;
      enableACME = false;

      extraConfig = ''
        location = /sw.js {
            return 404;
        }
        location = /service-worker.js {
            return 404;
        }
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:8085";
        proxyWebsockets = true;

        # Override the application's CSP header with our relaxed version
        extraConfig = ''
          proxy_hide_header Content-Security-Policy;
          add_header Content-Security-Policy $altered_csp always;
        '';
      };
    };
  };
}
