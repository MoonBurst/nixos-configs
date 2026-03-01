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
      cloudflare_token = { };
      matrix_macaroon_secret = { owner = "matrix-synapse"; };
      matrix_registration_secret = { owner = "matrix-synapse"; };
    };
  };


  systemd.services.cloudflared-matrix-tunnel = {
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
