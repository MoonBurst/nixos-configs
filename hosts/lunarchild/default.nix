{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [

    ../../modules/lunarchild-hardware.nix
    ../../modules/common/default.nix #Packages on both laptop and desktop
  ];
 
  environment.systemPackages = with pkgs; [

  ]; 

  
}
