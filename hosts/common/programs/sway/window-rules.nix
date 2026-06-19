{ ... }: {
  wayland.windowManager.sway.config = {
    assigns = {
      "1" = [ { class = "vesktop"; } ];
      "2" = [ { app_id = "edopro"; } ];
      "5" = [ { class = "Audacious"; } ];
    };

    window.commands = [
      # Generic rules first
      { command = "fullscreen 0"; criteria = { app_id = "edopro"; }; }
      { command = "allow_tearing yes"; criteria = { class = "^steam_app.*"; }; }
#      { command = "border pixel 1"; criteria = { class = ".*"; }; }
#    { command = "border pixel 1"; criteria = { app_id = ".*"; }; }
{ command = "border none"; criteria = { class = ".*"; }; }
{ command = "border none"; criteria = { app_id = ".*"; }; }

{ command = "floating enable, resize set 800 800"; criteria = { app_id = "satty"; }; }
      { command = "title_format \"[X11] %title\""; criteria = { shell = "xwayland"; }; }
      { command = "title_format \"[WL] %title\""; criteria = { shell = "xdg_shell"; }; }
#      { command = "inhibit_idle open"; criteria = { app_id = "gamescope"; title = "Overwatch"; }; }

      # FIXED DIMENSIONS RULE: Added an explicit "resize set 400 500" instruction here.
      # This forcefully overrides Sway's layout manager and creates a compact centered look.
{
  command = "floating enable, sticky enable, border none, border csd, resize set 700 500, move position center, focus";
  criteria = { app_id = "org.quickshell"; };
}

    ];
    workspaceLayout = "tabbed";
  };
}
