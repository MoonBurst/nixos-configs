{ pkgs, ... }:

{
  home-manager.users.moonburst = {
    home.packages = with pkgs; [ audacious ];

    systemd.user.services.audacious = {
      Unit = {
        Description = "Audacious music player daemon";
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.audacious}/bin/audacious -H";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
