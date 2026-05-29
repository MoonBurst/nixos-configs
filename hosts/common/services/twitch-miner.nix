{ config, pkgs, ... }:

{
  # 1. Enable Podman virtualization backend
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Allows docker-styled commands to link seamlessly
    defaultNetwork.settings.dns_enabled = true;
  };

  # 2. Declarative Multi-Container OCI Podman Setup
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {

      # Container Instance 1: Main Twitch Miner
      "twitch-miner" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        autoStart = true;
        ports = [
          "8082:8082" # Main application data listener port
          "5800:5800" # WebUI Port for logging in and captcha verification
        ];
        volumes = [
          "/var/lib/twitch-drops-miner/main:/TwitchDropsMiner/config"
        ];
        environment = {
          TZ = "America/New_York"; # Change this string value to match your local timezone
        };
      };

      # Container Instance 2: Berrydrop Twitch Miner
      "twitchminer-berrydrop" = {
        image = "docker.io/dungfu/twitch-drops-miner:latest";
        autoStart = true;
        ports = [
          "8084:8082" # Shifts internal container port to a unique host port to prevent network clashes
          "5801:5800" # Shifts WebUI to a unique port so both panels remain active concurrently
        ];
        volumes = [
          "/var/lib/twitch-drops-miner/berrydrop:/TwitchDropsMiner/config"
        ];
        environment = {
          TZ = "America/New_York"; # Change this string value to match your local timezone
        };
      };

    };
  };
}
