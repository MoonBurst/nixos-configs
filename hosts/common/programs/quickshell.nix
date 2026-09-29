{ config, lib, pkgs, ... }: {

  # =========================================================================
  # MODULAR FEATURE FLAGS
  # =========================================================================
  options.programs.quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell environment";
    package = lib.mkPackageOption pkgs "quickshell" { };

    features = {
      clipboard = lib.mkOption { type = lib.types.bool; default = true; description = "Clipboard history via cliphist"; };
      pass = lib.mkOption { type = lib.types.bool; default = true; description = "GPG password store via pass"; };
      email = lib.mkOption { type = lib.types.bool; default = true; description = "Email composition via himalaya"; };
      watermark = lib.mkOption { type = lib.types.bool; default = true; description = "Watermarking via imagemagick"; };
      ocr = lib.mkOption { type = lib.types.bool; default = true; description = "OCR text extraction via tesseract"; };
      recording = lib.mkOption { type = lib.types.bool; default = true; description = "Screen recording via wf-recorder"; };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional custom packages to make available for Quickshell";
    };
  };

  config = lib.mkIf config.programs.quickshell.enable {
    # -------------------------------------------------------------------------
    # 1. PAM AUTHENTICATION (Lockscreen Support)
    # -------------------------------------------------------------------------
    security.pam.services.quickshell = {
      allowNullPassword = false;
      startSession = true;
    };
  };
}
