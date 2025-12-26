# Forcing a source path update to resolve cache conflict
{
  description = "Moonburst's NixOS flake config";

  inputs = {
    # Primary Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
#    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Flake-parts for modular structure
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Niri (Wayland compositor) flake
    niri-flake = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
#Sherlock clipboard
        cypkgs = {
      url = "github:cybardev/nix-channel?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };



  outputs = {
    self,
    nixpkgs,
    flake-parts,
    niri-flake,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {inherit inputs;} ({system, ...}: {
      systems = ["x86_64-linux"];

      perSystem = {
        config,
        self',
        pkgs,
        lib,
        ...
      }: {
        # System-specific configuration can go here if needed
      };

      # Global flake configurations
      flake = {
        nixosConfigurations = {
          # 1. Desktop Host (moonbeauty)
          moonbeauty = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {inherit niri-flake;};
            modules = [
              ./hosts/moonbeauty/default.nix 
              ./hosts/common/default.nix
              ./hosts/moonbeauty/moonbeauty-hardware.nix 
            ];
          };

          # 2. Laptop Host (lunarchild)
          lunarchild = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {inherit niri-flake;};
            modules = [
              ./hosts/lunarchild/default.nix 
              ./hosts/common/default.nix
              ./hosts/lunarchild/lunarchild-hardware.nix 
            ];
          };
        };
      };
    });
}
