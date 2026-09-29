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
        description = "Per-process bandwidth tracking table in Network capsule via nethogs (with capabilities)";
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

    # -------------------------------------------------------------------------
    # 2. CAPABILITIES & PRIVILEGED WRAPPERS
    # -------------------------------------------------------------------------
    # When network monitoring is enabled, install /run/wrappers/bin/nethogs
    # with CAP_NET_RAW and CAP_NET_ADMIN so unprivileged users can read socket rates.
    programs.nethogs.enable = mkIf cfg.features.networkClientMonitoring (mkDefault true);

    # -------------------------------------------------------------------------
    # 3. SYSTEM PACKAGES
    # -------------------------------------------------------------------------
    environment.systemPackages = with pkgs; [
      cfg.package

      # Core system foundation for bar, hardware metrics, sound, and shell:
      pipewire        # Audio playback (`pw-play`) for alarm timers and cues
      wireplumber     # Volume, sink switcher, and mic control (`wpctl`)
      wl-clipboard    # Wayland clipboard manager (`wl-copy`, `wl-paste`)
      curl            # Weather forecasts (wttr.in) & Wiktionary REST queries
      python3         # Desktop scanner, GPU telemetry, and hardware discovery
      libnotify       # Desktop notification toasts (`notify-send`)
      gawk            # Clean hardware text stream parsing without subshell stalls
      procps          # Reliable `ps`, `pgrep`, `pkill` process tools
      coreutils       # `timeout`, `date`, `stat`, `realpath`
      iproute2        # Physical network route and default gateway detection (`ip`)
    ]
    # Conditional feature dependencies:
    ++ optional cfg.features.clipboard pkgs.cliphist
    ++ optional cfg.features.pass pkgs.pass
    ++ optional cfg.features.email pkgs.himalaya
    ++ optional cfg.features.watermark pkgs.imagemagick
    ++ optional cfg.features.ocr pkgs.tesseract
    ++ optional cfg.features.recording pkgs.wf-recorder
    ++ cfg.extraPackages;
  };
}
