{ ... }: {
  wayland.windowManager.sway.config = {
    assigns = {
      "1" = [ { class = "vesktop"; } ];
      "2" = [ { app_id = "edopro"; } ];
      "5" = [{ class = "Audacious"; }];
    };

    window.commands = [
      # Generic rules first
      { command = "fullscreen 0"; criteria = { app_id = "edopro"; }; }
      { command = "allow_tearing yes"; criteria = { class = "^steam_app.*"; }; }
      { command = "border pixel 1"; criteria = { class = ".*"; }; }
      { command = "border pixel 1"; criteria = { app_id = ".*"; }; }
      { command = "floating enable, resize set 800 800"; criteria = { app_id = "satty"; }; }
      { command = "title_format \"[X11] %title\""; criteria = { shell = "xwayland"; }; }
      { command = "title_format \"[WL] %title\""; criteria = { shell = "xdg_shell"; }; }
      { command = "inhibit_idle open"; criteria = { app_id = "gamescope"; title = "Overwatch"; }; }

      # WALKER OVERRIDES AT THE BOTTOM (HIGHEST PRIORITY)
      {
        command = "floating enable, sticky enable, border none, border csd, fullscreen disable, focus, opacity set 1, resize set 700 500, move position center";
        criteria = { app_id = "dev.benz.walker"; };
      }
      {
        command = "floating enable, sticky enable, border none, border csd, fullscreen disable, focus, opacity set 1, resize set 700 500, move position center";
        criteria = { app_id = "walker"; };
      }
      # Catching class just in case Sway is seeing it as an XWayland or generic window
      {
        command = "floating enable, sticky enable, border none, border csd, fullscreen disable, focus, opacity set 1, resize set 700 500, move position center";
        criteria = { class = "walker"; };
      }
    ];
    workspaceLayout = "tabbed";
  };
}
