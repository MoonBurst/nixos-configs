{ config, lib, pkgs, ... }: {

  # =========================================================================
  # 1. CORE DECLARATIONS
  # =========================================================================
  options.programs.quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell environment";
    package = lib.mkPackageOption pkgs "quickshell" { };
  };

  # =========================================================================
  # 2. SYSTEM CONFIGURATION
  # =========================================================================
  config = lib.mkIf config.programs.quickshell.enable {

    # -------------------------------------------------------------------------
    # Installs the packages globally for the system environment
    # -------------------------------------------------------------------------
    environment.systemPackages = [
      config.programs.quickshell.package
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.inotify-tools
      pkgs.pass
      pkgs.himalaya
      pkgs.imagemagick
      pkgs.tesseract
      pkgs.wf-recorder
    ];

    # -------------------------------------------------------------------------
    # FORCE SYMLINKS INTO YOUR USER PROFILE (Fixes Zsh Path Misses)
    # -------------------------------------------------------------------------
    users.users.moonburst.packages = [
      pkgs.cliphist
      pkgs.wl-clipboard
    ];

    # PAM AUTHENTICATION (Lockscreen Support)
    security.pam.services.quickshell = {
      allowNullPassword = false;
      startSession = true;
    };
  };
}
