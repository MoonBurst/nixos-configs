{ pkgs }: ''
  exec-once = ${pkgs.brave}/bin/brave
  exec-once = ${pkgs.vesktop}/bin/vesktop
  exec-once = ${pkgs.corectrl}/bin/corectrl
  exec-once = ${pkgs.quickshell}/bin/quickshell --path /home/moonburst/nix/hosts/common/programs/quickshell/shell.qml
  exec-once = ${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50
  exec-once = ${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10
''
