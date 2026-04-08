{ pkgs, lib, ... }:

let

  apps = with pkgs; {
    browser     = brave;
    editor      = kdePackages.kate;
    fileManager = nemo;
    imageViewer = qview;
    musicPlayer = vlc;
    pdfViewer   = brave;
    videoPlayer = vlc;
  };

  # This helper finds the .desktop filename inside the package automatically
  getDesktop = pkg:
    let
      appDir = "${pkg}/share/applications";
      # Check if the directory exists to prevent build errors
      files = if builtins.pathExists appDir
              then builtins.attrNames (builtins.readDir appDir)
              else [];
      # Find the first file ending in .desktop
      desktopFile = lib.findFirst (name: lib.hasSuffix ".desktop" name) "unknown" files;
    in
      desktopFile;

  # The Notifier Script
  mimeNotifier = pkgs.writeShellScriptBin "mime-fallback" ''
    MIME=$(${pkgs.xdg-utils}/bin/xdg-mime query filetype "$1" | cut -d';' -f1)
    ${pkgs.libnotify}/bin/notify-send \
      "MIME Refusal" \
      "Program for '$MIME' is missing or not set. Set it in mime.nix" \
      --icon=dialog-error
  '';

  # Helper: [ FoundDesktopFile, Notifier ]
  dumb = pkg: [ (getDesktop pkg) "mime-fallback.desktop" ];

in {
  # --- 3. SYSTEM LEVEL HOOKS ---
  environment.systemPackages = [
    mimeNotifier
    (pkgs.makeDesktopItem {
      name = "mime-fallback";
      desktopName = "MIME Notifier";
      exec = "${mimeNotifier}/bin/mime-fallback %u";
    })
  ];

  home-manager.users.moonburst = {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = lib.mkForce {
        # Web & Browser
        "text/html"              = dumb apps.browser;
        "x-scheme-handler/http"  = dumb apps.browser;
        "x-scheme-handler/https" = dumb apps.browser;
        "application/xhtml+xml"  = dumb apps.browser;

        # Audio
        "audio/flac"             = dumb apps.musicPlayer;
        "audio/x-flac"           = dumb apps.musicPlayer;
        "audio/mpeg"             = dumb apps.musicPlayer;
        "audio/mp3"              = dumb apps.musicPlayer;
        "audio/ogg"              = dumb apps.musicPlayer;
        "audio/wav"              = dumb apps.musicPlayer;

        # Video
        "video/mp4"              = dumb apps.videoPlayer;
        "video/mpeg"             = dumb apps.videoPlayer;
        "video/x-matroska"       = dumb apps.videoPlayer;
        "video/quicktime"        = dumb apps.videoPlayer;

        # Images
        "image/jpeg"             = dumb apps.imageViewer;
        "image/png"              = dumb apps.imageViewer;
        "image/webp"             = dumb apps.imageViewer;
        "image/gif"              = dumb apps.imageViewer;
        "image/bmp"              = dumb apps.imageViewer;

        # Documents & Files
        "application/pdf"        = dumb apps.pdfViewer;
        "inode/directory"        = dumb apps.fileManager;
        "text/plain"             = dumb apps.editor;
        "application/x-shellscript" = dumb apps.editor;
      };
    };
  };
}
