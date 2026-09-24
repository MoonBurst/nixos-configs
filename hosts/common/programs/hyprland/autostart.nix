{ pkgs, ... }:
let
  gpu6400 = "MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000:2b:00.0";
in
{
  wayland.windowManager.hyprland.extraConfig = ''
    -- Autostart
    hl.on("hyprland.start", function()
      -- Session var import (DISPLAY, WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
      -- XDG_SESSION_DESKTOP, XDG_DATA_DIRS, XDG_CONFIG_HOME, etc) is now
      -- handled declaratively via
      -- wayland.windowManager.hyprland.systemd.variables = [ "--all" ]
      -- in default.nix, so there's no manual dbus-update-activation-environment
      -- call needed here for that.
      hl.exec_cmd("${pkgs.bash}/bin/bash /home/moonburst/nix/hosts/common/scripts/wallpaper.sh daemon")
      hl.exec_cmd("quickshell ipc call lockscreen lock")
      hl.exec_cmd("${pkgs.vesktop}/bin/vesktop")
      hl.exec_cmd("${gpu6400} ${pkgs.steam}/bin/steam -nochatui -silent")
      -- This one still needs its own explicit re-export: gnome-keyring
      -- sets GNOME_KEYRING_CONTROL (and friends) dynamically once the
      -- daemon actually starts, which isn't known at the time the
      -- declarative --all import above runs, so it has to be re-synced
      -- after the fact.
      hl.exec_cmd("eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets) && ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all && systemctl --user start quickshell")
      hl.exec_cmd("${pkgs.corectrl}/bin/corectrl")
      hl.exec_cmd("${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50")
      hl.exec_cmd("${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10")
    end)
  '';
}
