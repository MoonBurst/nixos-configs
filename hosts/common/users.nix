{ config, pkgs, ... }:

{
  # --- Main User Account ---
  users.users.moonburst = {
    # Password managed via SOPS in security.nix
    # Use the absolute string path so the Flake doesn't try to "read" the file
    hashedPasswordFile = "/run/secrets/sops_key";
    isNormalUser = true;
    description = "MoonBurst";
    home = "/home/moonburst";

    # Permissions and hardware access
    extraGroups = [
      "networkmanager" "wheel" "audio" "video" "input"
      "render" "corectrl" "i2c" "libvirtd"
    ];

    # Default Shell
    shell = pkgs.zsh;

    # Hardcoded string paths for the authorized keys
    openssh.authorizedKeys.keyFiles = [
      "/run/secrets/laptop_public_key"
      "/run/secrets/desktop_public_key"
    ];
  };
}
