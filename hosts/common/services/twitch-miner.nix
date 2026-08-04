{ config, pkgs, ... }:

{
  # 1. Enable Podman virtualization backend
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # 2. Open necessary ports in the NixOS Firewall
  networking.firewall.allowedTCPPorts = [
    8082 5800 # Main Miner
    8084 5801 # Berrydrop Miner
  ];

  # 3. Automatically create directories on the host with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/twitch-drops-miner/main 0777 root root -"
    "d /var/lib/twitch-drops-miner/berrydrop 0777 root root -"
  ];

  # 4. Declarative Multi-Container OCI Podman Setup
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {

      # Container Instance 1: Main Twitch Miner
      "twitch-miner" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        autoStart = true;
        ports = [
          "8082:8082"
          "5800:5800"
        ];
        volumes = [
          "/var/lib/twitch-drops-miner/main:/TwitchDropsMiner/config"
        ];
        environment = {
          TZ = "America/Chicago";
        };
      };

      # Container Instance 2: Berrydrop Twitch Miner
      "twitchminer-berrydrop" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        autoStart = true;
        ports = [
          "8084:8082"
          "5801:5800"
        ];
        volumes = [
          "/var/lib/twitch-drops-miner/berrydrop:/TwitchDropsMiner/config"
        ];
        environment = {
          TZ = "America/Chicago";
        };
      };

    };
  };

# 5. Passwordless Sudo Rules for QuickShell Podman Monitoring
  security.sudo.extraRules = [
    {
      users = [ "moonburst" ]; # Your username
      commands = [
        {
          command = "/run/current-system/sw/bin/podman";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.podman}/bin/podman";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
