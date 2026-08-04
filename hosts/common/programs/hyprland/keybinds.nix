{ pkgs, lib, config, ... }:

let
  term = "${pkgs.ghostty}/bin/ghostty";
  lua = lib.generators.mkLuaInline;

  # Native hy3 workspace movement with follow = true option
  moveToWorkspace = target: ''hl.plugin.hy3.move_to_workspace("${target}", { follow = true })'';
in
{
  wayland.windowManager.hyprland.settings =
    let
      bind = key: action: { _args = [ key (lua action) ]; };
      bindo = key: action: opts: { _args = [ key (lua action) (lua opts) ]; };
      exec = cmd: ''hl.dsp.exec_cmd("${cmd}")'';
      ws = n: ''hl.dsp.focus({ workspace = "${n}" })'';

      # Native hy3 Lua API helpers
      hy3Focus = dir: ''hl.plugin.hy3.move_focus("${dir}")'';
      hy3Move = dir: ''hl.plugin.hy3.move_window("${dir}")'';
      hy3Group = action: ''hl.plugin.hy3.change_group("${action}")'';
      hy3Make = type: ''hl.plugin.hy3.make_group("${type}")'';
    in
    {
      bind = [
        # --- Core App Binds ---
        (bind "SUPER + Return" (exec "${term}"))
        (bind "SUPER + Q" (exec "${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/safekill.sh"))
        (bind "SUPER + SHIFT + Q" ''hl.dsp.window.close()'')
        (bind "SUPER + E" (exec "${pkgs.nemo}/bin/nemo"))
        (bind "SUPER + D" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call launcher toggle"))
        (bind "SUPER + K" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call clipboard toggle"))
        (bind "SUPER + SHIFT + K" (exec "save-replay"))
        (bind "SUPER + L" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock"))
        (bind "SUPER + M" (exec "sh -c 'echo toggle > /tmp/magnifier-state'"))
        (bind "SUPER + O" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call todo toggle"))
        (bind "SUPER + SHIFT + M" (exec "${pkgs.evolution}/bin/evolution"))

        # --- Fullscreen / Expand ---
        (bind "SUPER + F" ''hl.plugin.hy3.expand("fullscreen")'')

        # --- Quickshell Notifications ---
        (bind "SUPER + H" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif toggleHistory"))
        (bind "SUPER + Tab" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif jumpToLatest"))
        (bind "SUPER + Escape" (exec "quickshell -p /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif dismissLatest"))

        # --- Special Workspaces & Screenshots ---
        (bind "SUPER + SHIFT + minus" (moveToWorkspace "special"))
        (bind "SUPER + SHIFT + equal" ''hl.dsp.workspace.toggle_special()'')
        (bind "SUPER + SHIFT + S" (exec "qs -n -p /home/moonburst/nix/hosts/common/programs/quickshell/modules/overlays/quickshot"))

        # --- Workspaces ---
        (bind "SUPER + 1" (ws "1"))
        (bind "SUPER + 2" (ws "2"))
        (bind "SUPER + 3" (ws "3"))
        (bind "SUPER + 4" (ws "4"))
        (bind "SUPER + 5" (ws "5"))
        (bind "SUPER + 6" (ws "6"))
        (bind "SUPER + 7" (ws "7"))
        (bind "SUPER + 8" (ws "8"))

        (bind "SUPER + SHIFT + 1" (moveToWorkspace "1"))
        (bind "SUPER + SHIFT + 2" (moveToWorkspace "2"))
        (bind "SUPER + SHIFT + 3" (moveToWorkspace "3"))
        (bind "SUPER + SHIFT + 4" (moveToWorkspace "4"))
        (bind "SUPER + SHIFT + 5" (moveToWorkspace "5"))
        (bind "SUPER + SHIFT + 6" (moveToWorkspace "6"))
        (bind "SUPER + SHIFT + 7" (moveToWorkspace "7"))
        (bind "SUPER + SHIFT + 8" (moveToWorkspace "8"))

        # --- Native hy3 Directional Focus ---
        (bind "SUPER + A" (hy3Focus "l"))
        (bind "SUPER + S" (hy3Focus "r"))
        (bind "SUPER + Left" (hy3Focus "l"))
        (bind "SUPER + Right" (hy3Focus "r"))
        (bind "SUPER + Up" (hy3Focus "u"))
        (bind "SUPER + Down" (hy3Focus "d"))

        # --- Native hy3 Window Movement ---
        (bind "SUPER + SHIFT + Left" (hy3Move "l"))
        (bind "SUPER + SHIFT + Right" (hy3Move "r"))
        (bind "SUPER + SHIFT + Up" (hy3Move "u"))
        (bind "SUPER + SHIFT + Down" (hy3Move "d"))

        # --- Native hy3 Grouping & Tabbing ---
        (bind "SUPER + T" (hy3Group "toggletab"))
        (bind "SUPER + G" (hy3Make "h"))
        (bind "SUPER + V" (hy3Make "v"))
        (bind "SUPER + U" (hy3Group "untab"))

        # --- Audio & Media ---
        (bind "SUPER + 0" (exec "${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/toggle_mic.sh"))
        (bind "SUPER + minus" (exec "${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/sound_sink_switcher.sh"))
        (bindo "XF86AudioRaiseVolume" (exec "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70") ''{ locked = true, repeating = true }'')
        (bindo "XF86AudioLowerVolume" (exec "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") ''{ locked = true, repeating = true }'')
        (bindo "XF86AudioMute" (exec "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") ''{ locked = true }'')

        (bind "F11" (exec "bash /home/moonburst/nix/hosts/moonbeauty/programs/waybar/modules/music_portal.sh"))
        (bind "F10" (exec "${pkgs.mpc}/bin/mpc prev"))
        (bindo "XF86AudioMedia" (exec "${pkgs.mpc}/bin/mpc toggle") ''{ locked = true }'')
        (bindo "XF86AudioPlay" (exec "${pkgs.mpc}/bin/mpc toggle") ''{ locked = true }'')
        (bindo "XF86AudioStop" (exec "${pkgs.mpc}/bin/mpc stop") ''{ locked = true }'')
        (bindo "XF86AudioPrev" (exec "${pkgs.mpc}/bin/mpc prev") ''{ locked = true }'')
        (bindo "XF86AudioNext" (exec "${pkgs.mpc}/bin/mpc next") ''{ locked = true }'')
      ];
    };
}
