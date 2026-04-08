{ pkgs, ... }: 
let
  browser = "brave-browser.desktop";
  editor = "kate.desktop";
  fileManager = "nemo.desktop";
  terminal = "kitty.desktop";
  videoPlayer = "vlc.desktop";
  imageViewer = "com.interversehq.qView.desktop";
  mailClient = "org.gnome.Evolution.desktop";
in {
  xdg.configFile."mimeapps.list".force = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Browsers / Web
      "text/html" = browser;
      "x-scheme-handler/http" = browser;
      "x-scheme-handler/https" = browser;
      "x-scheme-handler/about" = browser;
      "x-scheme-handler/unknown" = browser;
      "x-scheme-handler/chrome" = browser;
      "application/xhtml+xml" = browser;

      # Development / Text
      "application/json" = editor;
      "application/yaml" = editor;
      "application/xml" = editor;
      "application/x-shellscript" = editor;
      "text/plain" = editor;
      "text/markdown" = editor;
      "inode/symlink" = editor;

      # Multimedia
      "audio/flac" = videoPlayer;
      "video/mp4" = videoPlayer;
      "image/gif" = imageViewer;
      "image/png" = imageViewer;
      "image/jpeg" = imageViewer;

      # Archives / Files
      "application/zip" = "org.gnome.FileRoller.desktop"; # Standard for Nemo/GNOME
      "application/vnd.rar" = "org.gnome.FileRoller.desktop";
      "inode/directory" = fileManager;

      # Communication / Protocols
      "x-scheme-handler/steam" = "steam.desktop";
      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/hyperbeam" = "hyperbeam.desktop";
      "x-scheme-handler/mailto" = mailClient;
    };

    associations.added = {
      "application/vnd.microsoft.portable-executable" = [ "wine.desktop" terminal ];
      "application/x-zerosize" = [ editor browser videoPlayer ];
    };
  };
}
