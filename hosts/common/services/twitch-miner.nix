{ pkgs, ... }:

{
  virtualisation.podman.enable = true;

  # Automatically creates the persistent folder with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/twitch-drops-miner 0755 root root -"
  ];

  virtualisation.oci-containers = {
    backend = "podman";
    containers."twitch-miner" = {
      image = "dungfu/twitch-drops-miner:latest";
      ports = [ "8082:8082" ]; 
      volumes = [
        "/var/lib/twitch-drops-miner:/app/output"
      ];
    };
  };
}
