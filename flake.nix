# Forcing a source path update to resolve cache conflict
{
  description = "Moonburst's NixOS flake config";

  inputs = {
    # Primary Nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    # Flake-parts for modular structure
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Niri (Wayland compositor) flake
    niri-flake = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom local programs flake
    local-packages = { # RENAMED: from custom-programs
      url = "path:./packages"; # RENAMED: from ./flake_programs
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-parts, niri-flake, local-packages, ... }@inputs:
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
            specialArgs = { inherit niri-flake local-packages; }; # Passes custom inputs to modules
            modules = [
              ./hosts/moonbeauty/default.nix # Updated path
              ./modules/common/default.nix
              ./modules/moonbeauty-hardware.nix # CORRECTED path
              ({ config, pkgs, ... }: {
                # Overlay to inject custom packages into the main pkgs set
                nixpkgs.overlays = [
                  (final: prev: {
                    sherlock-launcher = local-packages.packages.${final.system}.sherlock-launcher;
                    fchat-horizon = local-packages.packages.${final.system}.fchat-horizon;
                  })
                ];
              })
            ];
          };

          # 2. Laptop Host (lunarchild)
          lunarchild = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit niri-flake local-packages; };
            modules = [
              ./hosts/lunarchild/default.nix # Updated path
              ./modules/common/default.nix
              ./modules/lunarchild-hardware.nix # Updated file name
              ({ config, pkgs, ... }: {
                # Overlay to inject custom packages into the main pkgs set
                nixpkgs.overlays = [
                  (final: prev: {
                    sherlock-launcher = local-packages.packages.${final.system}.sherlock-launcher;
                    fchat-horizon = local-packages.packages.${final.system}.fchat-horizon;
                  })
                ];
              })
            ];
          };
        };
      };
    });
}
