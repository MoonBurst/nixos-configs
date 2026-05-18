{ pkgs, lib, ... }:

let
    # ░█░█░█▀█░█▀▄░▀█▀░█▀█░█▀▄░█░░░█▀▀░█▀▀
    # ░▀▄▀░█▀█░█▀▄░░█░░█▀█░█▀▄░█░░░█▀▀░▀▀█
    # ░░▀░░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀░░▀▀▀░▀▀▀░▀▀▀
  super = "Mod4";
  alt = "Mod1";
  term = "${pkgs.kitty}/bin/kitty";
  explorer = "${pkgs.nemo}/bin/nemo";
  music = "${pkgs.audacious}/bin/audacious";
  launchpad = "walker";
  scriptsDir = ../../scripts;
in
{
  wayland.windowManager.sway.config.keybindings = lib.mkOptionDefault {

# ░█▀█░█▀█░█▀█░░░█░░░█▀█░█░█░█▀█░█▀▀░█░█░█▀▀░█▀▄░█▀▀
# ░█▀█░█▀▀░█▀▀░░░█░░░█▀█░█░█░█░█░█░░░█▀█░█▀▀░█▀▄░▀▀█
# ░▀░▀░▀░░░▀░░░░░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀
    "${super}+Return" = "exec ${term}";
    "${super}+q" = "exec ${pkgs.bash}/bin/bash ${scriptsDir}/safekill.sh";
    "${super}+Shift+q" = "kill";
    "${super}+e" = "exec ${explorer}";
    "${super}+d" = "exec ${launchpad}";
    "${super}+l" = "exec ${pkgs.swaylock-effects}/bin/swaylock -f --screenshots --clock --indicator --indicator-radius 120 --indicator-thickness 15 --effect-blur 20x20 --effect-vignette 0:1 --ring-color 1a1a1a --key-hl-color ffff33 --ring-ver-color ffff33 --inside-ver-color 00000000 --ring-wrong-color ff0000 --inside-wrong-color 00000000 --bs-hl-color ff0000 --inside-color 00000000 --separator-color 00000000 --line-color 00000000 --text-color ffff33 --text-ver-color ffff33 --text-wrong-color ff0000 --text-clear-color ffff33 --text-caps-lock-color ffff33 --grace 5 --fade-in 2";
    "${super}+SHIFT+m" = "exec ${pkgs.evolution}/bin/evolution";
    "${super}+k" = "exec walker -m clipboard";
#    "${super}+k" = ''exec sh -c "CLIPHIST_DB_PATH=/tmp/cliphist_db sherlock-clp list | sherlock | xargs -r ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"'';

    # ░█▀▀░█░█░█▀▀░▀█▀░█▀▀░█▄█
    # ░▀▀█░░█░░▀▀█░░█░░█▀▀░█░█
    # ░▀▀▀░░▀░░▀▀▀░░▀░░▀▀▀░▀░▀
    # **Notifications (Dunst)**
   # "${super}+Escape" = "exec ${pkgs.dunst}/bin/dunstctl close";
   # "${super}+h" = "exec ${pkgs.dunst}/bin/dunstctl history-pop";
    #"${super}+Tab" = "exec ${pkgs.dunst}/bin/dunstctl action";

"${super}+Tab"    = "exec echo action > /run/user/1000/quickshell-input";
"${super}+Escape" = "exec echo "dismiss" > /tmp/qs_notification_pipe";






    # ░█▀▀░█▀▀░█▀▄░█▀▀░█▀▀░█▀█░█▀▀░█░█░█▀█░▀█▀
    # ░▀▀█░█░░░█▀▄░█▀▀░█▀▀░█░█░▀▀█░█▀█░█░█░░█░
    # ░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░░▀░
    "${super}+SHIFT+S" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp -d)\" - | ${pkgs.satty}/bin/satty -f - -o ~/Screenshots/%Y-%m-%d_%H:%M:%S.png --save-after-copy";
    "${super}+Shift+k" = "exec ${pkgs.obs-cmd}/bin/obs-cmd replay save && notify-send -i ${pkgs.obs-studio}/share/icons/hicolor/128x128/apps/com.obsproject.Studio.png 'OBS' 'Clip Saved!'";

    # ░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀
    # ░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀
    # ░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀
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

    "XF86AudioRaiseVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70";
    "XF86AudioLowerVolume" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    "XF86AudioMute" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
    "F10" = "exec ${pkgs.playerctl}/bin/playerctl --player audacious previous";
    "F11" = "exec bash /home/moonburst/nix/hosts/moonbeauty/programs/waybar/modules/music_portal.sh";
    "XF86AudioMedia" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
    "XF86AudioPlay" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
    "XF86AudioStop" = "exec ${pkgs.playerctl}/bin/playerctl stop";
    "XF86AudioPrev" = "exec ${pkgs.playerctl}/bin/playerctl previous";
    "XF86AudioNext" = "exec ${pkgs.playerctl}/bin/playerctl next";

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
