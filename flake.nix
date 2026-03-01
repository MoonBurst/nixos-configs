{
  description = "Moonburst's NixOS flake config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nur.url = "github:nix-community/NUR";

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

    moon-numix.url = "github:moonburst/moon-numix-icons";
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
    moon-numix,
    nur, # 2. Add nur here to the outputs arguments
  } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
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
              { nixpkgs.overlays = [ nur.overlays.default ]; }

              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.moonburst = { pkgs, ... }: {
                  imports = [
                    ./hosts/moonbeauty/packages.nix
                  ];

                  home.packages = [
                    inputs.moon-numix.packages.${pkgs.system}.default
                  ];

                  home.file.".local/share/icons/Numix".source =
                    "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix";

                  home.file.".local/share/icons/Numix-Light".source =
                    "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix-Light";

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
              stylix.nixosModules.stylix
              ./hosts/lunarchild/default.nix
              ./hosts/common/default.nix
              ./hosts/common/theme.nix
              ./hosts/lunarchild/lunarchild-hardware.nix

              { nixpkgs.overlays = [ nur.overlays.default ]; }

              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.moonburst = { pkgs, ... }: {
                  home.packages = [
                    inputs.moon-numix.packages.${pkgs.system}.default
                  ];

                  home.file.".local/share/icons/Numix".source =
                    "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix";

                  home.file.".local/share/icons/Numix-Light".source =
                    "${inputs.moon-numix.packages.${pkgs.system}.default}/share/icons/Numix-Light";

                  home.stateVersion = "25.11";
                };
              }
            ];
          };
        };
      };
    });
}
