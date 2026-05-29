{ pkgs, ... }:

{
  virtualisation.podman.enable = true;

  systemd.tmpfiles.rules = [
    "d /var/lib/twitch-drops-miner/main 0755 root root -"
    "d /var/lib/twitch-drops-miner/berrydrop 0755 root root -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      
      "twitch-miner" = {
        image = "dungfu/twitch-drops-miner:latest";
        ports = [ "8082:8082" ]; # Dashboard at http://localhost:8082
        volumes = [
          "/var/lib/twitch-drops-miner/main:/app/output"
        ];
      };

      "twitchminer-berrydrop" = {
        image = "dungfu/twitch-drops-miner:latest";
        ports = [ "8084:8082" ]; # Dashboard at http://localhost:8084
        volumes = [
          "/var/lib/twitch-drops-miner/berrydrop:/app/output"
        ];
      };

    };
  };
}
