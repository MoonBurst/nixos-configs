{ pkgs, ... }:

{
 services.greetd = {
    enable = true;
    settings = {
      # 1. Add this block for automatic login on boot
      initial_session = {
        command = "${pkgs.sway}/bin/sway";
        user = "moonburst"; # Your username from the terminal prompt
      };
      
      # 2. This is your existing fallback session when you manually log out
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --cmd sway";
        user = "greeter";
      };
    };
  };
  
}
