{ pkgs, ... }:

{
  # Activates the system-level daemon
  programs.corectrl = {
    enable = true;
  };

  # Configures AMD overclock masks (replaced the old programs.corectrl option)
  hardware.amdgpu.overdrive.enable = true;

  # Direct rule definition to authorize the authenticated user group
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.corectrl.helper.init" ||
           action.id == "org.corectrl.helper.set") &&
          subject.isInGroup("corectrl")) {
        return polkit.Result.YES;
      }
    });
  '';
}
