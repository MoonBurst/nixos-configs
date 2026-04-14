{ pkgs, config, lib, ... }:

{
  home-manager.users.moonburst = {
    services.swayidle = {
      enable = true;
      systemdTarget = "sway-session.target";

      events = [
        {
          event = "after-resume";
          command = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
        }
      ];

      timeouts = [
        {
          timeout = 120;
          command = "if ${pkgs.procps}/bin/pgrep -x swaylock; then ${pkgs.sway}/bin/swaymsg 'output * dpms off'; fi";
          resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
        }
      ];
    };
  };
}
