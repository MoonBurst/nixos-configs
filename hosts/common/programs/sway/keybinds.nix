{ pkgs, lib, config, ... }:

let
    # ░█░█░█▀█░█▀▄░▀█▀░█▀█░█▀▄░█░░░█▀▀░█▀▀
    # ░█▀▄░█▀█░█▀▄░░█░░█▀█░█▀▄░█░░░█▀▀░▀▀█
    # ░░▀░░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀░░▀▀▀░▀▀▀░▀▀▀
  super = "Mod4";
  alt = "Mod1";

  # SAFELY RESOLVE: Falls back gracefully if Home Manager evaluates this isolated from the NixOS options tree
  targetTerminal = if builtins.hasAttr "apps" config && builtins.hasAttr "terminal" config.apps
                   then config.apps.terminal
                   else pkgs.ghostty;

  targetFileManager = if builtins.hasAttr "apps" config && builtins.hasAttr "fileManager" config.apps
                      then config.apps.fileManager
                      else pkgs.nemo;

  term = "${targetTerminal}/bin/${targetTerminal.pname or targetTerminal.name or "ghostty"}";
  explorer = "${targetFileManager}/bin/${targetFileManager.pname or targetFileManager.name or "nemo"}";
  music = "${pkgs.audacious}/bin/audacious";
  scriptsDir = ../../scripts;
in
{
  wayland.windowManager.sway.config.keybindings = lib.mkOptionDefault {

# ░█▀█░█▀█░█▀█░░░█░░░█▀█░█░█░█▀█░█▀▀░█░█░█▀▀░█▀▄░█▀▀
# ░█▀█░█▀▀░█▀▀░░░█░░░█▀█░█░█░█░█░█░░░█▀█░█▀▀░█▀▄░▀▀█
# ░▀░▀░▀░░░▀░░░░░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀
    "${super}+Return" = "exec ${term}";
    "${super}+q" = "exec ${pkgs.bash}/bin/bash ${scriptsDir}/safekill.sh";
    "${super}+Shift+q" = "kill";
    "${super}+e" = "exec ${explorer}";
    "${super}+d" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call launcher toggle";
    "${super}+k" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call clipboard toggle";
    "${super}+Shift+k" = "exec save-replay";
    "${super}+l" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call lockscreen lock";
    "${super}+m" = "exec sh -c 'echo toggle > /tmp/magnifier-state'";
    "${super}+o" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call todo toggle";
    "${super}+SHIFT+m" = "exec ${pkgs.evolution}/bin/evolution";

    # ░█▀▀░█░█░█▀▀░▀█▀░█▀▀░█▄█
    # ░▀▀█░░█░░▀▀█░░█░░█▀▀░█░█
    # ░▀▀▀░░▀░░▀▀▀░░▀░░▀▀▀░▀░▀
    "${super}+h" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif toggleHistory";


        "${super}+Tab"     = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif jumpToLatest";
        "${super}+Escape" = "exec quickshell -p ~/nix/hosts/common/programs/quickshell/shell.qml ipc call global_notif dismissLatest";
        "${super}+Shift+minus" = "move scratchpad";
        "${super}+Shift+Equal" = "scratchpad show";


    # ░█▀▀░█▀▀░█▀▄░█▀▀░█▀▀░█▀█░█▀▀░█░█░█▀█░▀█▀
    # ░▀▀█░█░░░█▀▄░█▀▀░█▀▀░█░█░▀▀█░█▀█░█░█░░█░
    # ░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░
   # "${super}+SHIFT+S" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp -d)\" - | ${pkgs.satty}/bin/satty -f - -o ~/Screenshots/%Y-%m-%d_%H:%M:%S.png --save-after-copy";
   "${super}+SHIFT+S" = "exec qs -n -p ~/nix/hosts/common/programs/quickshell/modules/overlays/quickshot";

    # ░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀
    # ░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀
    # ░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀░▀
    # **Workspace Navigation**
    "${super}+1" = "workspace number 1";
    "${super}+2" = "workspace number 2";
    "${super}+3" = "workspace number 3";
    "${super}+4" = "workspace number 4";
    "${super}+5" = "workspace number 5";
    "${super}+6" = "workspace number 6";
    "${super}+7" = "workspace number 7";
    "${super}+8" = "workspace number 8";

    # **Window Focus**
    "${super}+a" = "focus left";
    "${super}+Down" = "focus down";
    "${super}+Up" = "focus up";
    "${super}+s" = "focus right";

    # **Window Movement**
    "${super}+Shift+Left" = "move left";
    "${super}+Shift+Down" = "move down";
    "${super}+Shift+Up" = "move up";
    "${super}+Shift+Right" = "move right";

    # **Move Container to Workspace**
    "${super}+Shift+1" = "move container to workspace number 1; workspace number 1;";
    "${super}+Shift+2" = "move container to workspace number 2; workspace number 2;";
    "${super}+Shift+3" = "move container to workspace number 3; workspace number 3;";
    "${super}+Shift+4" = "move container to workspace number 4; workspace number 4;";
    "${super}+Shift+5" = "move container to workspace number 5; workspace number 5;";
    "${super}+Shift+6" = "move container to workspace number 6; workspace number 6;";
    "${super}+Shift+7" = "move container to workspace number 7; workspace number 7;";
    "${super}+Shift+8" = "move container to workspace number 8; workspace number 8;";

    # ░█▄█░█▀▀░█▀▄░▀█▀░█▀█
    # ░█░█░█▀▀░█░█░░█░░█▀█
    # ░▀░▀░▀▀▀░▀▀░░▀▀▀░▀░▀
    # **Media & Audio**
    "${super}+0" = "exec ${pkgs.bash}/bin/bash ${scriptsDir}/toggle_mic.sh";
    "${super}+minus" = "exec ${pkgs.bash}/bin/bash ${scriptsDir}/sound_sink_switcher.sh";

# Volume Controls (Keeping global PipeWire system volume controls)
    "XF86AudioRaiseVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70";
    "XF86AudioLowerVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    "XF86AudioMute"        = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

    # Music Portal Script
    "F11" = "exec bash /home/moonburst/nix/hosts/moonbeauty/programs/waybar/modules/music_portal.sh";

    # MPD Media Key Controls
    "F10"             = "exec ${pkgs.mpc}/bin/mpc prev";
    "XF86AudioMedia"  = "exec ${pkgs.mpc}/bin/mpc toggle";
    "XF86AudioPlay"   = "exec ${pkgs.mpc}/bin/mpc toggle";
    "XF86AudioStop"   = "exec ${pkgs.mpc}/bin/mpc stop";
    "XF86AudioPrev"   = "exec ${pkgs.mpc}/bin/mpc prev";
    "XF86AudioNext"   = "exec ${pkgs.mpc}/bin/mpc next";

    # **Mouse Cursor Emulation**
    "${super}+Control+Left"   = "seat - cursor move -10 0";
    "${super}+Control+Right"  = "seat - cursor move 10 0";
    "${super}+Control+Up"     = "seat - cursor move 0 -10";
    "${super}+Control+Down"   = "seat - cursor move 0 10";

    # **Mouse Clicks**
    "--no-repeat f3" = "seat - cursor press button1";
    "--release f3"   = "seat - cursor release button1";
  };
}
