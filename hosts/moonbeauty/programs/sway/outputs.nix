{ ... }:

{
  wayland.windowManager.sway.config = {
    # Monitor Configurations
    output = {
      "LG Electronics LG ULTRAWIDE 0x0003CBC2" = {
        mode = "2560x1080@60.0Hz";
        pos = "4480 0";
        transform = "180";
        scale = "1.0";
        adaptive_sync = "on";
      };
      "HGC CR270HDM 0x00000001" = {
        mode = "2560x1440@164.998Hz";
        pos = "1920 0";
        transform = "180";
        scale = "1.0";
        adaptive_sync = "off";
      };
      "AOC 24G2W1G4 0x0000E8FA" = {
        mode = "1920x1080@144.001Hz";
        pos = "0 0";
        transform = "180";
        scale = "1.0";
        adaptive_sync = "on";
      };
    };

    # Workspace-to-Monitor Pinning
    workspaceOutputAssign = [
      { workspace = "1"; output = "AOC 24G2W1G4 0x0000E8FA"; }
      { workspace = "2"; output = "HGC CR270HDM 0x00000001"; }
      { workspace = "3"; output = "LG Electronics LG ULTRAWIDE 0x0003CBC2"; }
      { workspace = "4"; output = "AOC 24G2W1G4 0x0000E8FA"; }
      { workspace = "5"; output = "HGC CR270HDM 0x00000001"; }
      { workspace = "6"; output = "LG Electronics LG ULTRAWIDE 0x0003CBC2"; }
      { workspace = "7"; output = "AOC 24G2W1G4 0x0000E8FA"; }
      { workspace = "8"; output = "HGC CR270HDM 0x00000001"; }
      { workspace = "9"; output = "LG Electronics LG ULTRAWIDE 0x0003CBC2"; }
    ];

    #focus.mouseWarp = false; # Common preference for multi-monitor
  };
}
