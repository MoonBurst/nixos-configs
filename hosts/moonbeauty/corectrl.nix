{ pkgs, ... }:

{
  # Activates the system-level daemon and configures AMD overclock masks
  programs.corectrl = {
    enable = true;
    gpuOverclock.enable = true;
  };

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
