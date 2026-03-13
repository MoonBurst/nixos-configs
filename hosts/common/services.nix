{ config, pkgs, lib, ... }:

{
  imports =
    let
      subDir = ./services;
      files = if builtins.pathExists subDir then builtins.readDir subDir else {};
      nixFiles = lib.filterAttrs (name: type:
        type == "regular" &&
        lib.hasSuffix ".nix" name
      ) files;
    in
    # Use path concatenation (+) to maintain the "path" type
    lib.mapAttrsToList (name: _: subDir + "/${name}") nixFiles;
}
