{ pkgs, ... }:

{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          # Overload: hold for control, tap for control.
          # The 'horizon_macros' layer is active while held.
          leftcontrol = "overload(horizon_macros, leftcontrol)";
        };
        "horizon_macros:C" = {
          # 1. Blue Quote (Standard ASCII macro)
         "apostrophe" = "macro([ 5ms c 5ms o 5ms l 5ms o 5ms r 5ms = 5ms b 5ms l 5ms u 5ms e 5ms ] 5ms \" 5ms [ 5ms / 5ms c 5ms o 5ms l 5ms o 5ms r 5ms ])";


          # 2. ♪ (Prior/PageUp) - Hex 266a
          "pageup" = "macro(C-S-u 2 6 6 a enter)";

          # 3. ゴ (Next/PageDown) - Hex 30B4
          "pagedown" = "macro(C-S-u 3 0 b 4 enter)";

          # 4. ● (Numpad 7) - Hex 25CF
          "kp7" = "macro(C-S-u 2 5 c f enter)";
        };
      };
    };
  };

  # Required permissions and packages
  users.users.moonburst.extraGroups = [ "keyd" "input" "uinput" ];
  hardware.uinput.enable = true;
  environment.systemPackages = [ pkgs.keyd ];

  system.stateVersion = "25.11";
}
