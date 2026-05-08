{
  description = "Moonburst's NixOS flake config";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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

    elephant.url = "github:abenz1267/elephant";
    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };
    sops-nix.url = "github:Mic92/sops-nix";
    moon-numix.url = "github:moonburst/moon-numix-icons";
  };

  outputs = { self, nixpkgs, flake-parts, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
      systems = [ "x86_64-linux" ];
      flake = {
        nixosConfigurations = {


          moonbeauty = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              ./hosts/moonbeauty/default.nix
              { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
              inputs.home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; inherit (inputs) nixpkgs-unstable; };
                home-manager.users.moonburst = { pkgs, ... }: {
                  imports = [ ./hosts/moonbeauty/packages.nix ];
                  home.stateVersion = "25.11";
                };
              }
            ];
          };



        lunarchild = nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.hostPlatform = "x86_64-linux"; }
              ./hosts/lunarchild/default.nix
              { nixpkgs.overlays = [ inputs.nur.overlays.default ]; }
              inputs.home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = { inherit inputs; inherit (inputs) nixpkgs-unstable; };
                home-manager.users.moonburst = { pkgs, ... }: {
                  home.stateVersion = "25.11";
                };
              }
            ];
          };





        };
      };
    }
  );
}
