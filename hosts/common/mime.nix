{ pkgs, lib, config, ... }:

let
  apps = {
    browser     = pkgs.chromium;
    editor      = pkgs.kdePackages.kate;
    fileManager = pkgs.nemo;
    imageViewer = pkgs.qview;
    musicPlayer = pkgs.vlc;
    pdfViewer   = pkgs.librewolf;
    videoPlayer = pkgs.vlc;
    terminal    = pkgs.ghostty;
  };

  # Find the canonical .desktop file for a package, skipping the
  # autostart / handler / service / portal variants that are
  # NoDisplay=true and often don't declare the MIME type we want.
  #
  # Previously this used lib.findFirst on the raw readDir output, which
  # sorts alphabetically — for pkgs.nemo that picked
  # "nemo-autostart.desktop" before "nemo.desktop", breaking inode/directory.
  # Same class of bug would hit any package with an autostart variant.
  getDesktop = pkg:
    let
      appDir = "${pkg}/share/applications";
      pname  = pkg.pname or (lib.getName pkg);
      files  = if builtins.pathExists appDir
               then builtins.attrNames (builtins.readDir appDir)
               else [];
      usable = lib.filter (n:
        lib.hasSuffix ".desktop" n
        && !(lib.hasInfix "autostart" n)
        && !(lib.hasInfix "handler" n)
        && !(lib.hasInfix "service" n)
        && !(lib.hasInfix "portal" n)
      ) files;
      exactName = "${pname}.desktop";
      kdeName   = "org.kde.${pname}.desktop";
      ordered =
        lib.optional (builtins.elem exactName usable) exactName
        ++ lib.optional (builtins.elem kdeName usable) kdeName
        ++ usable;
    in
      if ordered == []
      then throw "mime.nix: no usable .desktop file found in ${appDir} for ${pname}"
      else builtins.head ordered;

  mimeNotifier = pkgs.writeShellScriptBin "mime-fallback" ''
    MIME=$(${pkgs.xdg-utils}/bin/xdg-mime query filetype "$1" | cut -d';' -f1)
    ${pkgs.libnotify}/bin/notify-send \
      "MIME Refusal" \
      "Program for '$MIME' is missing or not set. Set it in mime.nix" \
      --icon=dialog-error
  '';

  dumb = pkg: [ (getDesktop pkg) "mime-fallback.desktop" ];

in {
  options.apps = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = {};
    description = "Centralized applications list owned by mime.nix";
  };

  config = {
    apps = apps;

    environment.systemPackages = [
      mimeNotifier
      (pkgs.makeDesktopItem {
        name = "mime-fallback";
        desktopName = "MIME Notifier";
        exec = "${mimeNotifier}/bin/mime-fallback %u";
      })
    ];

    environment.variables = {
      TERMINAL = "${apps.terminal.pname or apps.terminal.name or "ghostty"}";
    };

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
          "image/jxl"              = dumb apps.imageViewer;

          # Documents & Files
          "application/pdf"        = dumb apps.pdfViewer;
          "text/plain"             = dumb apps.editor;
          "application/x-shellscript" = dumb apps.editor;
          "x-scheme-handler/terminal" = dumb apps.terminal;

          # Now resolves to "nemo.desktop" automatically — the
          # getDesktop filter drops "nemo-autostart.desktop".
          "inode/directory"        = dumb apps.fileManager;
        };
      };
    };
  };
}
