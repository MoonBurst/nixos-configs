{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ audacious ];

  systemd.user.services.audacious = {
    description = "Audacious music player daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.audacious}/bin/audacious -H";
      Restart = "on-failure";
    };
  };
}
