{ config, pkgs, ... }:

{
  # Enable the dconf system service
  programs.dconf.enable = true;

  # Install Nemo and thumbnailers system-wide
  environment.systemPackages = with pkgs; [
    nemo

    # Thumbnailers
    ffmpegthumbnailer      # Video files
    gnome-epub-thumbnailer  # EPUB/e-book files
    evince                 # PDF previews
    librsvg                # SVG images
    webp-pixbuf-loader     # WebP images
    libgsf                 # ODF (Office) files
    gdk-pixbuf             # General image formats
  ];

  # System-wide dconf defaults for Nemo using the dconf user profile
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/nemo/preferences" = {
          "show-image-thumbnails" = "always";
          "thumbnail-limit" = "104857600"; # 100MB
        };
      };
    }
  ];

  # System-wide GTK3 CSS override using Stylix base05 color.
  environment.etc."xdg/gtk-3.0/gtk.css".text = let
    base05 = config.lib.stylix.colors.withHashtag.base05;
  in ''
    /* Target Nemo canvas items (icon view labels) */
    .nemo-canvas-item {
      color: ${base05};
    }

    /* Target Nemo main window text, sidebar elements, and list/tree views */
    .nemo-window,
    .nemo-window label,
    .nemo-window treeview,
    .nemo-places-sidebar,
    .nemo-desktop {
      color: ${base05};
    }

    /* Force dialog and action buttons to use base05 text */
    dialog button,
    dialog button label,
    .dialog button,
    .dialog button label,
    messagedialog button,
    messagedialog button label,
    .nemo-window button,
    .nemo-window button label {
      color: ${base05} !important;
    }
  '';
}
