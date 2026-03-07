{ config, pkgs, inputs, lib, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    # NIXOS NATIVE: Uses hardware SSH keys to unlock the vault.
    # No more manual key files needed once this is active!
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # Optional Fallback: Look for the manual key if the hardware key fails
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";

    secrets = {
      sops_key.neededForUsers = true;
      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";

      # Write keys directly to the system directory SSH trusts for 'moonburst'
      laptop_public_key = {
        path = "/etc/ssh/authorized_keys.d/moonburst_laptop";
        mode = "0444";
      };
      desktop_public_key = {
        path = "/etc/ssh/authorized_keys.d/moonburst_desktop";
        mode = "0444";
      };

      # Only define Matrix/Cloudflare secrets if we are on the desktop
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

  # Ensures the directory and keys are accessible to the system service
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

  # --- SSH Server (Trusting the keys) ---
  services.openssh = {
    enable = true;
    authorizedKeysFiles = [
      "/etc/ssh/authorized_keys.d/moonburst_laptop"
      "/etc/ssh/authorized_keys.d/moonburst_desktop"
    ];
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- SSH Client Configuration ---
  programs.ssh = {
    startAgent = false; # FIXED: Avoid conflict with GPG agent
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
    enableSSHSupport = true;
  };

  programs.fuse.userAllowOther = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    sops age pass authenticator cloudflared
  ];
}
