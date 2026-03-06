{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
    # Password managed via SOPS in security.nix
    hashedPasswordFile = config.sops.secrets.sops_key.path;
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";

    # Permissions and hardware access
    extraGroups = [
      "networkmanager" # Internet control
      "wheel"          # Sudo access
      "audio"          # Sound devices
      "video"          # Webcam/GPU access
      "input"          # Keyboard/Mouse events
      "render"         # GPU acceleration
      "corectrl"       # AMD Overclocking/Profiles
      "i2c"            # DDC/CI & RGB control
      "libvirtd"       # Virtual Machine management
    ];

    # Default Shell
    shell = pkgs.zsh;

    # Fix for Flake Pure Evaluation:
    # Use a command to pull keys from runtime secrets instead of keyFiles
    openssh.authorizedKeys.keys = [
       # This tells Nix: "This user is managed by the command below"
    ];
  };

  # Configure SSH to pull keys from the decrypted sops files at runtime
  services.openssh.authorizedKeysCommand = ''
    /run/current-system/sw/bin/bash -c 'cat ${config.sops.secrets.laptop_public_key.path} ${config.sops.secrets.desktop_public_key.path}'
  '';
  services.openssh.authorizedKeysCommandUser = "root";
}
