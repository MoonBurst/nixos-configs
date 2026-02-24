{
  description = "Moonburst's NixOS flake config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    stylix = {
      url = "github:danth/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    niri-flake = {
      url = "github:YaLTeR/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
    stylix,
    home-manager,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ system, ... }: {
      systems = [ "x86_64-linux" ];
      flake = {
        nixosConfigurations = {
          # 1. Desktop Host (moonbeauty)
          moonbeauty = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              stylix.nixosModules.stylix
              ./hosts/moonbeauty/default.nix
               ./hosts/common/theme.nix

              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.moonburst = {
                  imports = [
                ./hosts/moonbeauty/packages.nix
                ./hosts/common/theme.nix
                ];
                  gtk.enable = true;
                  qt.enable = true;
                  stylix.enable = true;
                  stylix.targets.sway.enable = true;
                  stylix.targets.kitty.enable = true;
                  stylix.targets.gtk.enable = true;

                  home.stateVersion = "25.11";
                };
              }
            ];
          };

          # 2. Laptop Host (lunarchild)
          lunarchild = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = { inherit inputs; };
            modules = [
              ./hosts/lunarchild/default.nix
              ./hosts/common/default.nix
              ./hosts/lunarchild/lunarchild-hardware.nix

              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.moonburst = {
                  stylix.targets.sway.enable = true;
                  stylix.targets.kitty.enable = true;
                  stylix.targets.gtk.enable = true;
                  home.stateVersion = "25.11";
                };
              }
            ];
          };
        };
      };
    });
}
