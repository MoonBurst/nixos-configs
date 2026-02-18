{ config, pkgs, inputs, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
    secrets = {
      sops_key = {
        neededForUsers = true;
      };
      # Adding these here since they are in your common secrets file
      weather_api_key = { owner = "moonburst"; };
      weather_city = { owner = "moonburst"; };
    };
  };

  # --- Shared Programs & Security ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Essential for certain file mounts/users
  programs.fuse.userAllowOther = true;

  # Core security services
  security.polkit.enable = true;
  security.rtkit.enable = true;


    environment.systemPackages = with pkgs; [
    sops # To edit/view encrypted files
    age  # To manage keys
    pass #to manage passwords
  ];
}


