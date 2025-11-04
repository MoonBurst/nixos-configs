{
  description = "System multi-host configurations";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    
    niri-flake.url = "github:sodiboo/niri-flake"; 
    
    niri-flake.inputs.nixpkgs.follows = "nixpkgs"; 
  };
	
  outputs = { self, nixpkgs, flake-parts, niri-flake, ... } @ inputs:
  {
    nixosConfigurations = {
      "moonbeauty" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/desktop/default.nix
        ];
        specialArgs = { inherit niri-flake; };
      };
      
      "lunarchild" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/laptop/default.nix
        ];
      };
    };
  };
}
