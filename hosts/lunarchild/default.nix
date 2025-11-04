{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [

    ../../hosts/lunarchild/lunarchild-hardware.nix
    ../../hosts/common/default.nix #Packages on both laptop and desktop
  ];
 
  environment.systemPackages = with pkgs; [

  ]; 

  
}
