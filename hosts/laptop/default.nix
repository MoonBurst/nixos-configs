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
  # ====================================================================
  # WAYBAR
  # ====================================================================
  systemd.user.services.waybar = {
    enable = true;
    description = "Waybar System Tray";
    serviceConfig = {
      ExecStart = ''
        ${pkgs.waybar}/bin/waybar \
        -c ${(pkgs.writeTextDir "share/waybar/config" (builtins.readFile (../../modules/programs/waybar/lunarchild)))}/share/waybar/config \
        -s ${(pkgs.writeTextDir "share/waybar/style.css" (builtins.readFile (../../modules/programs/waybar/style.css)))}/share/waybar/style.css
      '';
    };
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };
 
  
  
  environment.systemPackages = with pkgs; [

  ]; 

  
}
