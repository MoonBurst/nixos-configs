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
  };
}
