{ config, pkgs, lib, ... }:

{
  # 1. Podman backend (needed for OCI containers + auto-update + auto-prune)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = lib.mkForce false;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Podman Auto-Update Timer
  systemd.timers.podman-auto-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # 2. Firewall ports for the two miner web UIs
  networking.firewall.allowedTCPPorts = [
    8082 5800 # Main Miner (MoonBurst)
    8084 5801 # Berrydrop Miner (Berrydropx)
  ];

  # 3. Writable data dirs (session files live here)
  systemd.tmpfiles.rules = [
    "d /var/lib/twitch-drops-miner/main 0777 root root -"
    "d /var/lib/twitch-drops-miner/berrydrop 0777 root root -"
  ];

  # 4. Declarative OCI containers
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      "twitch-miner" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        extraOptions = [ "--dns=10.88.0.1" ];
        autoStart = true;
        labels = {
          "io.containers.autoupdate" = "registry";
        };
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

      "twitchminer-berrydrop" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        extraOptions = [ "--dns=10.88.0.1" ];
        autoStart = true;
        labels = {
          "io.containers.autoupdate" = "registry";
        };
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

  # 5. Passwordless sudo for podman (used by the miner's auto-heal + by you for management)
  security.sudo.extraRules = [
    {
      users = [ "moonburst" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/podman";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.podman}/bin/podman";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
