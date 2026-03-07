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
    cypkgs = {
      url = "github:cybardev/nix-channel?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    moon-numix.url = "github:moonburst/moon-numix-icons";
  };

  outputs = { self, nixpkgs, flake-parts, sops-nix, cypkgs, stylix, home-manager, moon-numix, nur, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
      systems = [ "x86_64-linux" ];

      # ADDED: This defines the tools direnv will load into your shell automatically
      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            sops
            age
            mkpasswd
            ssh-to-age
          ];
        };
      };

      flake = {
        nixosConfigurations = {
          moonbeauty = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              sops-nix.nixosModules.sops
              ./hosts/moonbeauty/default.nix
              ./hosts/common/theme.nix
              { nixpkgs.overlays = [ nur.overlays.default ]; }
              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.users.moonburst = { pkgs, ... }: {
                  imports = [ ./hosts/moonbeauty/packages.nix ];
                  home.packages = [
                    inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default
                    pkgs.kitty.terminfo
                  ];
                  home.file.".local/share/icons/Numix".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix";
                  home.file.".local/share/icons/Numix-Light".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix-Light";
                  home.stateVersion = "25.11";
                };
              }
            ];
          };

          lunarchild = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              sops-nix.nixosModules.sops
              ./hosts/lunarchild/default.nix
              ./hosts/common/default.nix
              ./hosts/common/theme.nix
              ./hosts/lunarchild/lunarchild-hardware.nix
              { nixpkgs.overlays = [ nur.overlays.default ]; }
              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.users.moonburst = { pkgs, ... }: {
                  home.packages = [
                    inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default
                    pkgs.kitty.terminfo
                  ];
                  home.file.".local/share/icons/Numix".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix";
                  home.file.".local/share/icons/Numix-Light".source = "${inputs.moon-numix.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/icons/Numix-Light";
                  home.stateVersion = "25.11";
                };
              }
            ];
          };
        };
      };
    });
}
