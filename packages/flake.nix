{
  description = "Local Nix packages for Moonburst's configuration";

  inputs = {
    # Ensure this flake follows the main nixpkgs input
    nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        # Define the custom packages defined in this directory
        sherlock-launcher = pkgs.callPackage ./sherlock-launcher.nix { };
        fchat-horizon = pkgs.callPackage ./fchat-horizon.nix { };
      }
    );
  };
}
