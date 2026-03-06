{ config, lib, pkgs, ... }:

{
  networking.hostName = "lunarchild";

  imports = [
    ./lunarchild-hardware.nix
    ../common/default.nix
  ]; # Added missing closing bracket here

  # ====================================================================
  # SERVICES (Laptop Specific)
  # ====================================================================
  # Updated to modern settings structure
  services.logind.settings.Login = {
    HandleLidSwitch = "poweroff";
    HandleLidSwitchExternalPower = "lock";
  };

  # Enable battery/power management
  services.upower.enable = true;
  services.thermald.enable = true; # Helps keep the laptop cool

  # ====================================================================
  # ENVIRONMENT AND PACKAGES
  # ====================================================================
  environment.systemPackages = with pkgs; [
    brightnessctl       # Control screen brightness from terminal/Waybar
    playerctl           # Control music/audio (Lunar Child's flacs!)
    powertop            # Monitor power consumption
  ];

  system.stateVersion = "25.11";
}
