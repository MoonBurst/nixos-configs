{
  description = "Local Nix packages for Moonburst's configuration";

  inputs = {
    nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        sherlock-launcher = pkgs.callPackage ./sherlock-launcher.nix { };
        fchat-horizon = pkgs.callPackage ./fchat-horizon.nix { };
      }
    );
  };
}
