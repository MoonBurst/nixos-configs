{ config, pkgs, lib, ... }:

let
  domain = "moonburst.net";
  ssoDomain = "login.moonburst.net";
  registerDomain = "register.moonburst.net";
in {
  sops.secrets = {
    authelia_jwt_secret = { owner = "authelia-main"; };
    authelia_session_secret = { owner = "authelia-main"; };
    authelia_storage_key = { owner = "authelia-main"; };
    authelia_oidc_hmac_secret = { owner = "authelia-main"; };
    authelia_oidc_private_key = { owner = "authelia-main"; };

    lldap_admin_password = {
      owner = "root";
      group = "root";
      mode = "0444";
    };

    lldap_smtp_password = {
      owner = "root";
      key = "lldap_smtp_password";
    };

    lldap_authelia_bind_password = {
      owner = "authelia-main";
      key = "lldap_admin_password";
    };
  };

  sops.templates."lldap_config.toml" = {
    owner = "root";
    group = "root";
    mode = "0444";
    content = ''
      ldap_base_dn = "dc=moonburst,dc=net"
      http_port = 17170
      ldap_port = 3890
      key_file = "/var/lib/lldap/key_file"
      ldap_user_pass_file = "${config.sops.secrets.lldap_admin_password.path}"
      registration_open = true

      [smtp_options]
      smtp_encryption = "TLS"
      host = "smtp.gmail.com"
      port = 465
      user = "moonburstplays@gmail.com"
      from = "moonburstplays@gmail.com"
      password = "${config.sops.placeholder.lldap_smtp_password}"
    '';
  };

  services.lldap = {
    enable = true;
    silenceForceUserPassResetWarning = true;
    settings = {
      ldap_base_dn = "dc=moonburst,dc=net";
      ldap_user_pass_file = config.sops.secrets.lldap_admin_password.path;
    };
  };

  systemd.services.lldap = {
    serviceConfig.ExecStart = lib.mkForce "${pkgs.lldap}/bin/lldap run --config-file ${config.sops.templates."lldap_config.toml".path}";
  };

  services.authelia.instances.main = {
    enable = true;
    secrets = {
      jwtSecretFile = config.sops.secrets.authelia_jwt_secret.path;
      sessionSecretFile = config.sops.secrets.authelia_session_secret.path;
      storageEncryptionKeyFile = config.sops.secrets.authelia_storage_key.path;
      oidcHmacSecretFile = config.sops.secrets.authelia_oidc_hmac_secret.path;
      oidcIssuerPrivateKeyFile = config.sops.secrets.authelia_oidc_private_key.path;
    };

    settings = {
      theme = "dark";
      server.address = "tcp://127.0.0.1:9091";
      storage.local.path = "/var/lib/authelia-main/db.sqlite3";

      authentication_backend = {
        ldap = {
          address = "ldap://127.0.0.1:3890";
          implementation = "custom";
          base_dn = "dc=moonburst,dc=net";
          additional_users_dn = "ou=people";
          users_filter = "(&(|({username_attribute}={input})({mail_attribute}={input}))(objectClass=person))";
          additional_groups_dn = "ou=groups";
          groups_filter = "(member={dn})";
          attributes = {
            username = "uid";
            display_name = "displayName";
            mail = "mail";
            group_name = "cn";
          };
          user = "cn=admin,ou=people,dc=moonburst,dc=net";
        };
      };

      session = {
        cookies = [
          {
            domain = "moonburst.net";
            authelia_url = "https://login.moonburst.net";
          }
        ];
      };

      notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";

      access_control = {
        default_policy = "deny";
        rules = [
          {
            domain = [ "${ssoDomain}" ];
            policy = "bypass";
          }
          {
            domain = [ "*.${domain}" ];
            policy = "one_factor";
          }
        ];
      };

      identity_providers.oidc = {
        clients = [
          {
            client_id = "conduwuit";
            client_name = "Conduwuit Matrix";
            client_secret = "$pbkdf2-sha512$310000$c2FsdHNhbHQ$...";
            public = false;
            authorization_policy = "one_factor";
            scopes = [ "openid" "profile" "email" ];
            redirect_uris = [
              "https://moonburst.net/_matrix/client/unstable/org.matrix.msc2965/auth_issuer/response"
            ];
            userinfo_signed_response_alg = "none";
          }
        ];
      };
    };
  };

  systemd.services."authelia-main" = {
    serviceConfig.Environment = [
      "AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE=${config.sops.secrets.lldap_authelia_bind_password.path}"
    ];
  };

  services.nginx.virtualHosts = {
    "${ssoDomain}" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:9091";
        proxyWebsockets = true;
      };
    };

    "${registerDomain}" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } { addr = "[::]"; port = 80; } ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:17170";
        proxyWebsockets = true;
      };
    };
  };
}
