{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [

    ../../modules/laptop-hardware.nix
    ../../modules/common/default.nix #Packages on both laptop and desktop
  ];
 
  # ====================================================================
  # WAYBAR
  # ====================================================================
  {
  programs.waybar = {
    enable = true;
    settings = {
      main = {
        config = builtins.readFile .config/waybar/lunarchild;
        style = builtins.readFile .config/waybar/style.css;
      };
    };
  };
  
  
  environment.systemPackages = with pkgs; [

  ]; 

  
}
