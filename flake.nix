{
  description = "Moonburst's NixOS flake config";

  inputs = {
    # Primary Nixpkgs
   # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
   nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Flake-parts for modular structure
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Niri (Wayland compositor) flake
    niri-flake = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sherlock clipboard
    cypkgs = {
      url = "github:cybardev/nix-channel?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    niri-flake,
    sops-nix,
    cypkgs,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ system, ... }: {
      systems = [ "x86_64-linux" ];

      perSystem = { config, self', pkgs, lib, ... }: {
        # System-specific configuration can go here if needed
      };

      # Global flake configurations
      flake = {
        nixosConfigurations = {
          # 1. Desktop Host (moonbeauty)
          moonbeauty = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            # We pass 'inputs' so common/default.nix can find sops-nix
            specialArgs = { inherit inputs niri-flake cypkgs; };
            modules = [
              ./hosts/moonbeauty/default.nix
            ];
          };

          # 2. Laptop Host (lunarchild)
          lunarchild = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs niri-flake cypkgs; };
            modules = [
              ./hosts/lunarchild/default.nix
              # It's better to import common/default.nix INSIDE lunarchild/default.nix
              # but keeping it here for now to ensure it builds.
              ./hosts/common/default.nix
              ./hosts/lunarchild/lunarchild-hardware.nix
            ];
          };
        };
      };
    });
}
