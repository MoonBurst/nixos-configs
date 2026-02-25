{ ... }:

{
  wayland.windowManager.sway.config = {
    # Automatic workspace assignments
    assigns = {
      #"1" = [ { class = "vesktop"; } ];
      "2" = [ { app_id = "edopro"; } ];
      "1" = [ { app_id = "nemo"; } ];
    };

    # Window-specific behaviors (for_window)
    window.commands = [
      { command = "fullscreen 0"; criteria = { app_id = "edopro"; }; }
      { command = "allow_tearing yes"; criteria = { class = "^steam_app.*"; }; }
      { command = "border pixel 1"; criteria = { class = ".*"; }; }
      { command = "border pixel 1"; criteria = { app_id = ".*"; }; }
      { command = "floating enable, resize set 800 800"; criteria = { app_id = "satty"; }; }
      { command = "title_format \"[X11] %title\""; criteria = { shell = "xwayland"; }; }
      { command = "title_format \"[WL] %title\""; criteria = { shell = "xdg_shell"; }; }
      { command = "inhibit_idle open"; criteria = { app_id = "gamescope"; title = "Overwatch"; }; }
    ];

    # Default layout for new workspaces
    workspaceLayout = "tabbed";
  };
}
