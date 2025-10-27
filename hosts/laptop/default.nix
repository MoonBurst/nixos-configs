{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [

    ../../modules/laptop-hardware.nix
    #../../modules/desktop-kernel.nix #I didn't make this. Not sure if I will.
    ../../modules/common/default.nix 
  ];
 
  

  services.xserver.enable = true; 

  environment.systemPackages = with pkgs; [

  ]; 

  
}
