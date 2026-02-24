{ pkgs, ... }:

let
  # Define your GPU Environment Variables as Nix strings
  gpu7900 = "MESA_VK_DEVICE_SELECT=1002:744c! DRI_PRIME=pci-0000:28:00.0";
  gpu6400 = "MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000:2b:00.0";
in
{
  wayland.windowManager.sway.config.startup = [
    # **░█▀▀░▀█▀░█▀█░█▀▄░▀█▀░█░█░█▀█**
    # **░▀▀█░░█░░█▀█░█▀▄░░█░░█░█░█▀▀**
    # **░▀▀▀░░▀░░▀░▀░▀░▀░░▀░░▀▀▀░▀░░**

    # **Applications**
    { command = "${pkgs.vivaldi}/bin/vivaldi"; }
    { command = "${pkgs.vesktop}/bin/vesktop"; }
    { command = "${pkgs.corectrl}/bin/corectrl"; }

    # **GPU Specific Launches**
    # OBS using the 6400 for encoding
#  { command = "${gpu6400} ${pkgs.obs-studio}/bin/obs"; }
    # Steam using the 6400
#    { command = "${gpu6400} ${pkgs.steam}/bin/steam -nochatui -silent"; }

    # **Background Services**
#    { command = "${pkgs.swayidle}/bin/swayidle"; }

    # **Clipboard Management (Cliphist)**
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store -max-items 50"; }
    { command = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store -max-items 10"; }

    # **Scripts & Daemons**
    # { command = "sherlock --daemonize"; always = true; }
  ];
}
