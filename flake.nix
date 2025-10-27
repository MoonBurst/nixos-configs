  description = "System multi-host configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      # Target: moonburst@moonbeauty (Desktop)
      "moonbeauty" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/desktop/default.nix
        ];
      };

      # Target: moonburst@lunarchild (Laptop)
   #   "lunarchild" = nixpkgs.lib.nixosSystem {
   #     system = "x86_64-linux";
   #     modules = [
   #       ./hosts/laptop/default.nix
   #     ];
    #  };
    };
  };

