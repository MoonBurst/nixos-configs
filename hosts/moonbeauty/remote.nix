{ pkgs, config, ... }: {
  sops.age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
  sops.secrets.remote_to_moon_pc_token = {};

  systemd.services.cloudflare-tunnel = {
    description = "Cloudflare Tunnel for moonburst.net";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      # Use a shell script to read the secret file directly into the command
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c "exec ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token $(cat ${config.sops.secrets.remote_to_moon_pc_token.path})"
      '';

      Restart = "always";
      RestartSec = "5s";
      User = "root";
    };
  };

  environment.systemPackages = [ pkgs.cloudflared ];
}
