{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    -- Monitors Layout (Left-to-Right layout tracking using unrotated landscape widths)
    hl.monitor({ output = "DP-2", mode = "1920x1080@144.001", position = "0x0", scale = 1, transform = 2 })
    hl.monitor({ output = "DP-1", mode = "2560x1440@164.998", position = "1920x0", scale = 1, transform = 2 })
    hl.monitor({ output = "HDMI-A-2", mode = "2560x1080@60", position = "4480x0", scale = 1, transform = 2 })

    -- Workspace Monitor Layout Assignments (Left = DP-2, Middle = DP-1, Right = HDMI-A-2)
    hl.workspace_rule({ workspace = "1", monitor = "DP-2", default = true })
    hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
    hl.workspace_rule({ workspace = "7", monitor = "DP-2" })

    hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true })
    hl.workspace_rule({ workspace = "5", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "8", monitor = "DP-1" })

    hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-2", default = true })
    hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2" })
    hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-2" })
  '';
}
