{ config, pkgs, ... }:

{
  # 1. Install the package
  environment.systemPackages = [ pkgs.walker ];

  # 2. Entirely contained configuration
  home-manager.users.moonburst = {
    # This writes ~/.config/walker/config.toml
    home.file.".config/walker/config.toml".text = ''
      # General UI Settings
      ui.fullscreen = true
      ui.width = 1650
      ui.height = 500

      [search]
      placeholder = "Search Applications, Clipboard (c), or Web (?)..."

      # Enable specific modules
      [[modules]]
      name = "applications"
      prefix = ""

      [[modules]]
      name = "clipboard"
      prefix = "c "

      [[modules]]
      name = "websearch"
      prefix = "? "

      [[modules]]
      name = "commands"
      prefix = "> "
    '';

    # This writes ~/.config/walker/style.css using Stylix colors
    home.file.".config/walker/style.css".text = with config.lib.stylix.colors; ''
      /* Reset window background to transparent */
      #window {
        background-color: rgba(0, 0, 0, 0);
      }

      /* The main visual container */
      #box {
        background-color: #${base00};
        border: 2px solid #${base0D};
        border-radius: 12px;
        padding: 16px;
      }

      /* Search input field */
      #search {
        color: #${base05};
        background-color: #${base01};
        border: 1px solid #${base02};
        border-radius: 8px;
        padding: 8px;
        margin-bottom: 12px;
      }

      /* Individual list items */
      #entry {
        padding: 8px;
        border-radius: 6px;
      }

      /* Label text color */
      #text {
        color: #${base05};
      }

      /* Subtext/Description color */
      #subtext {
        color: #${base04};
      }

      /* The currently selected item */
      #selected {
        background-color: #${base0D};
      }

      /* Ensure text on selected item is readable (Base00 is your dark bg) */
      #selected #text, #selected #subtext {
        color: #${base00};
      }

      /* Styling for the icons */
      #icon {
        margin-right: 10px;
      }
    '';
  };
}
