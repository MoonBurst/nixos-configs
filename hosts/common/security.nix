{ config, pkgs, inputs, lib, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";

    secrets = {
      moonburst_password = { neededForUsers = true; };
      sops_key = { neededForUsers = true; };
      borg_passphrase = { neededForUsers = true; };
      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";
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

  systemd.services.sops-nix.after = [ "openssh.service" ];
  systemd.tmpfiles.rules = [
    "d /home/moonburst/.config/sops/age 0700 moonburst users - -"
  ];


  # --- SSH Server Settings ---
  services.openssh = {
    enable = true;
    # Fix: Removed the problematic IPv6 address
    listenAddresses = [
      { addr = "0.0.0.0"; port = 22; }
    ];
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      GatewayPorts = "yes";
    };
  };

  # --- SSH Client Configuration ---
  programs.ssh = {
    startAgent = false;
    extraConfig = ''
      Host moonburst.net
        HostName moonburst.net
        User moonburst
        Port 22
        CheckHostIP no
        HostKeyAlias moonbeauty
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        ProxyCommand ${pkgs.cloudflared}/bin/cloudflared access ssh --hostname %h

      Host moonbeauty
        HostName moonbeauty
        User moonburst

      Host lunarchild
        HostName lunarchild
        User moonburst
    '';
  };

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
