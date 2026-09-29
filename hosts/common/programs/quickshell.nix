{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.quickshell;
in {
  options.programs.quickshell = {
    enable = mkEnableOption "Quickshell desktop shell environment";

    package = mkPackageOption pkgs "quickshell" { };

    # =========================================================================
    # MODULAR FEATURE FLAGS
    # =========================================================================
    features = {
      clipboard = mkOption {
        type = types.bool;
        default = true;
        description = "Clipboard history & previews via cliphist";
      };

      pass = mkOption {
        type = types.bool;
        default = true;
        description = "GPG password store integration via pass";
      };

      email = mkOption {
        type = types.bool;
        default = true;
        description = "Email manager and composition overlay via himalaya";
      };

      watermark = mkOption {
        type = types.bool;
        default = true;
        description = "Quickshot steganographic watermark stamping via imagemagick";
      };

      ocr = mkOption {
        type = types.bool;
        default = true;
        description = "Quickshot OCR text extraction via tesseract";
      };

      recording = mkOption {
        type = types.bool;
        default = true;
        description = "Screen recording detection in Unified Monitor via wf-recorder";
      };

      networkClientMonitoring = mkOption {
        type = types.bool;
        default = true;
        description = "Per-process bandwidth tracking table in Network capsule via nethogs";
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional custom packages to make available in the environment for Quickshell";
    };
  };

  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # 1. PAM AUTHENTICATION (WlSessionLock Lockscreen Support)
    # -------------------------------------------------------------------------
    # Grants Quickshell permission to verify passwords for the lockscreen
    security.pam.services.quickshell = {
      allowNullPassword = false;
      startSession = true;
    };
  };
}
