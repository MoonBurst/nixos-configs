{ pkgs, ... }:

let
  gpu7900 = "MESA_VK_DEVICE_SELECT=1002:744c! DRI_PRIME=pci-0000:28:00.0";
  gpu6400 = "MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000:2b:00.0";
in
{
  wayland.windowManager.sway.config.startup = [
    # **░█▀▀░▀█▀░█▀█░█▀▄░▀█▀░█░█░█▀█**
    # **░▀▀█░░█░░█▀█░█▀▄░░█░░█░█░█▀▀**
    # **░▀▀▀░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░░**

    # **Applications**
#  { command = "${pkgs.brave}/bin/brave"; }
    { command = "${pkgs.vesktop}/bin/vesktop"; }
# { command = "horizon-electron --password-store=gnome-libsecret"; }
    # **GPU Specific Launches**
    # Steam using the 6400
   { command = "${gpu6400} ${pkgs.steam}/bin/steam -nochatui -silent"; }

# **Background Services**
    { command = "eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets) && dbus-update-activation-environment --systemd --all && systemctl --user start quickshell"; }
    { command = "${pkgs.corectrl}/bin/corectrl"; }
    # **Clipboard Management (Cliphist)**
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50"; }
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10"; }

  ];
}
