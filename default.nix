# /etc/nixos/default.nix

{ pkgs }: {
  # This part is the attribute set being returned
  fchat-horizon = pkgs.callPackage ./fchat-horizon.nix {};
  
}
