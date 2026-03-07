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
      moonburst_password = { neededForUsers = true; };
      sops_key = { neededForUsers = true; };
      borg_passphrase = { neededForUsers = true; };
      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";

      # The specific token for your Cloudflare SSH Tunnel
      remote_to_moon_pc_token = { };

      # Desktop-only secrets (Moonbeauty)
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

  # --- Cloudflare Tunnel Service (MoonPC SSH Server Side) ---
  systemd.services.cloudflared-ssh-tunnel = {
    description = "Cloudflare Tunnel for SSH on MoonPC";
    after = [ "network.target" "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # Bypassing EnvironmentFile because SOPS secrets are raw strings.
      # We use Bash to cat the secret file directly into the --token argument.
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(${pkgs.coreutils}/bin/cat ${config.sops.secrets.remote_to_moon_pc_token.path})'";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "root";
    };
  };

  # --- SSH Server Settings ---
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
      # Connecting from the outside world via Cloudflare
      Host moonpc
        HostName ssh.moonburst.net
        User moonburst
        ProxyCommand ${pkgs.cloudflared}/bin/cloudflared access ssh --hostname %h

      # Local network aliases
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
    enableSSHSupport = true;
  };

  programs.fuse.userAllowOther = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    sops age pass authenticator cloudflared
  ];
}
