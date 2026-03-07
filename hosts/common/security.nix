{ config, pkgs, inputs, lib, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
    secrets = {
      sops_key.neededForUsers = true;
      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";

      # Write keys directly to the system directory SSH trusts for 'moonburst'
      # This bypasses the Flake evaluation restriction on /run
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

  # --- Shared Programs & Security ---
  # FIX: Disable conflicting GNOME agent to let GnuPG handle SSH
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
