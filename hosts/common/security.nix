{ config, pkgs, inputs, lib, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    # NIXOS NATIVE: Uses hardware SSH keys to unlock the vault.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Optional Fallback
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";

    secrets = {
      moonburst_password = {
        neededForUsers = true;
      };

      sops_key = {
        neededForUsers = true;
      };

      borg_passphrase = {
        neededForUsers = true;
      };

      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";

      # Desktop-only secrets
      cloudflare_token = lib.mkIf (config.networking.hostName == "moonbeauty") { };
      matrix_macaroon_secret = lib.mkIf (config.networking.hostName == "moonbeauty") {
        owner = "matrix-synapse";
        group = "root";
      };
      matrix_registration_secret = lib.mkIf (config.networking.hostName == "moonbeauty") {
        owner = "matrix-synapse";
        group = "root";
      };
    };
  };

  # Force SOPS to wait for SSH keys to be ready
  systemd.services.sops-nix.after = [ "openssh.service" ];

  # Ensures the directory and keys are accessible
  systemd.tmpfiles.rules = [
    "d /home/moonburst/.config/sops/age 0700 moonburst users - -"
  ];

  # --- Services (Desktop Specific) ---
  systemd.services.cloudflared-matrix-tunnel = lib.mkIf (config.networking.hostName == "moonbeauty") {
    description = "Cloudflare Tunnel for Matrix";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = [ config.sops.secrets.cloudflare_token.path ];
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token \${cloudflare_token}";
      Restart = "on-failure";
      User = "root";
    };
  };

  # --- SSH Server ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- SSH Client Configuration ---
  programs.ssh = {
    startAgent = false;
    extraConfig = ''
      Host moonbeauty
        HostName moonbeauty
        User moonburst

      Host lunarchild
        HostName lunarchild
        User moonburst
    '';
  };

  # --- Shared Programs & Security ---
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.gnome.gcr-ssh-agent.enable = false;

  programs.gnupg.agent = {
    enable = true;
    # THIS ENABLES GPG TO ACT AS THE SSH AGENT:
    enableSSHSupport = true;
  };

  programs.fuse.userAllowOther = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    sops age pass authenticator cloudflared
  ];
}
