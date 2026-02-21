{ pkgs, ... }: {
  # 1. Install the theme assets
  environment.systemPackages = with pkgs; [
    papirus-icon-theme
    hicolor-icon-theme
    kdePackages.breeze-icons
    librsvg
  ];
  fonts = {
    packages = with pkgs; [
      fira-sans                  # Clean sans-serif
      font-awesome               # Icons for Waybar
      roboto                     # Standard UI font
      jetbrains-mono              # Coding font
      noto-fonts                 # Universal coverage
      noto-fonts-color-emoji      # Emojis
      material-symbols           # UI Icons
      material-icons              # More UI Icons
      # Nerd Fonts (Specific icons for terminal/Waybar)
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.enable = true;
};

    # 2. Force GTK to use these themes globally (System-wide configs)
  environment.etc."gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-icon-theme-name=Papirus-Dark
    gtk-theme-name=Moon-Burst-Theme
    gtk-application-prefer-dark-theme=1
  '';

  # 3. Set environment variables for Wayland/Sway sessions
  environment.sessionVariables = {
    GTK_THEME                            = "Moon-Burst-Theme";
    GTK_ICON_THEME                  = "Papirus-Dark";
    XCURSOR_THEME                   = "";

    XDG_DATA_DIRS = [ "${pkgs.papirus-icon-theme}/share" ];
  };
}
