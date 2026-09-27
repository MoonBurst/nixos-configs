{ pkgs, ... }:

let
  gpu7900 = "MESA_VK_DEVICE_SELECT=1002:744c! DRI_PRIME=pci-0000_28_00_0";
  gpu6400 = "MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000_2b_00_0";
in
{
  wayland.windowManager.sway.config.startup = [
    # **░█▀▀░▀█▀░█▀█░█▀▄░▀█▀░█░█░█▀█**
    # **░▀▀█░░█░░█▀█░█▀▄░░█░░█░█░█▀▀**
    # **░▀▀▀░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░░**

    # **Applications**
#  { command = "${pkgs.brave}/bin/brave"; }
    { command = "${gpu6400} ${pkgs.vesktop}/bin/vesktop --render-node-override=/dev/dri/renderD129"; }
# { command = "horizon-electron --password-store=gnome-libsecret"; }
    # **GPU Specific Launches**
    # Steam using the 6400
   { command = "${gpu6400} ${pkgs.steam}/bin/steam -nochatui -silent"; }

# **Background Services**
    { command = "eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets) && dbus-update-activation-environment --systemd --all MESA_VK_DEVICE_SELECT DRI_PRIME && systemctl --user start quickshell"; }
    { command = "${pkgs.corectrl}/bin/corectrl"; }
    # **Clipboard Management (Cliphist)**
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50"; }
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10"; }

  ];
}
