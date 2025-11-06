{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [

    ../../hosts/lunarchild/lunarchild-hardware.nix
    ../../hosts/common/default.nix #Packages on both laptop and desktop
  ];
  # ====================================================================
  # SERVICES
  # ====================================================================
	services.logind.lidSwitch = "poweroff";
	services.logind.lidSwitchExternalPower = "lock";


  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
	environment.systemPackages = with pkgs; [

  ]; 

  
}
