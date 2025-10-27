# ~/nixos-config/hosts/laptop/default.nix
{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [
    # System-level modules
    ../../modules/laptop-hardware.nix
    ../../modules/laptop-kernel.nix
    ../../modules/common/default.nix
  ];


  # Example of configuring a laptop-specific service
  services.power-profiles-daemon.enable = true;

}
