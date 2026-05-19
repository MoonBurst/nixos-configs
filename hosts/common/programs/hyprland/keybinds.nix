{ pkgs }: ''
  bind = $mod, Return, exec, ${pkgs.kitty}/bin/kitty
  bind = $mod, q, exec, ${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/safekill.sh
  bind = $mod SHIFT, q, killactive
  bind = $mod, e, exec, ${pkgs.nemo}/bin/nemo
  bind = $mod, d, exec, walker
  bind = $mod, l, exec, ${pkgs.swaylock-effects}/bin/swaylock -f --screenshots --clock --indicator --indicator-radius 120 --indicator-thickness 15 --effect-blur 20x20 --effect-vignette 0:1 --ring-color 1a1a1a --key-hl-color ffff33 --ring-ver-color ffff33 --inside-ver-color 00000000 --ring-wrong-color ff0000 --inside-wrong-color 00000000 --bs-hl-color ff0000 --inside-color 00000000 --separator-color 00000000 --line-color 00000000 --text-color ffff33 --text-ver-color ffff33 --text-wrong-color ff0000 --text-clear-color ffff33 --text-caps-lock-color ffff33 --grace 5 --fade-in 2
  bind = $mod SHIFT, m, exec, ${pkgs.evolution}/bin/evolution
  bind = $mod, k, exec, walker -m clipboard
  bind = $mod, Tab, exec, echo "action" > /tmp/qs_notification_pipe
  bind = $mod, Escape, exec, echo "dismiss" > /tmp/qs_notification_pipe
  bind = $mod SHIFT, S, exec, ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp -d)" - | ${pkgs.satty}/bin/satty -f - -o ~/Screenshots/%Y-%m-%d_%H:%M:%S.png --save-after-copy
  bind = $mod SHIFT, k, exec, ${pkgs.obs-cmd}/bin/obs-cmd replay save && notify-send -i ${pkgs.obs-studio}/share/icons/hicolor/128x128/apps/com.obsproject.Studio.png 'OBS' 'Clip Saved!'
  
  bind = $mod, f, fullscreen, 0
  bind = $mod SHIFT, f, fullscreen, 1

  bind = $mod SHIFT, minus, movetoworkspace, special:scratchpad
  bind = $mod SHIFT, equal, togglespecialworkspace, scratchpad

  bind = $mod, 1, workspace, 1
  bind = $mod, 2, workspace, 2
  bind = $mod, 3, workspace, 3
  bind = $mod, 4, workspace, 4
  bind = $mod, 5, workspace, 5
  bind = $mod, 6, workspace, 6
  bind = $mod, 7, workspace, 7
  bind = $mod, 8, workspace, 8
  bind = $mod, a, movefocus, l
  bind = $mod, Down, movefocus, d
  bind = $mod, Up, movefocus, u
  bind = $mod, s, movefocus, r
  bind = $mod SHIFT, Left, movewindow, l
  bind = $mod SHIFT, Down, movewindow, d
  bind = $mod SHIFT, Up, movewindow, u
  bind = $mod SHIFT, Right, movewindow, r
  bind = $mod SHIFT, 1, movetoworkspace, 1
  bind = $mod SHIFT, 2, movetoworkspace, 2
  bind = $mod SHIFT, 3, movetoworkspace, 3
  bind = $mod SHIFT, 4, movetoworkspace, 4
  bind = $mod SHIFT, 5, movetoworkspace, 5
  bind = $mod SHIFT, 6, movetoworkspace, 6
  bind = $mod SHIFT, 7, movetoworkspace, 7
  bind = $mod SHIFT, 8, movetoworkspace, 8
  bind = $mod, 0, exec, ${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/toggle_mic.sh
  bind = $mod, minus, exec, ${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/sound_sink_switcher.sh
  bind = , XF86AudioRaiseVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 0.70
  bind = , XF86AudioLowerVolume, exec, ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  bind = , XF86AudioMute, exec, ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  bind = , F10, exec, ${pkgs.playerctl}/bin/playerctl --player audacious previous
  bind = , F11, exec, bash /home/moonburst/nix/hosts/moonbeauty/programs/waybar/modules/music_portal.sh
  bind = , XF86AudioMedia, exec, ${pkgs.playerctl}/bin/playerctl play-pause
  bind = , XF86AudioPlay, exec, ${pkgs.playerctl}/bin/playerctl play-pause
  bind = , XF86AudioStop, exec, ${pkgs.playerctl}/bin/playerctl stop
  bind = , XF86AudioPrev, exec, ${pkgs.playerctl}/bin/playerctl previous
  bind = , XF86AudioNext, exec, ${pkgs.playerctl}/bin/playerctl next
  binde = $mod CONTROL, Left, movecursor, -10 0
  binde = $mod CONTROL, Right, movecursor, 10 0
  binde = $mod CONTROL, Up, movecursor, 0 -10
  binde = $mod CONTROL, Down, movecursor, 0 10

  # Mouse Dragging Bindings (bindm)
  bindm = $mod, mouse:272, movewindow
  bindm = $mod, mouse:273, resizewindow
''
