# /etc/nixos/mounts.nix (FIXED)
{ config, lib, pkgs, ... }:

{
  # Mount 3TB Btrfs HDD for general storage
  fileSystems."/mnt/3TBHDD" = {
    # UUID for /dev/sdb2
    device = "/dev/disk/by-uuid/2771f69c-effd-4d1d-afd3-8940399ae700";
    fsType = "btrfs";
    options = [ 
      "noatime"
      "nofail"
    ];
  };

  # Mount secondary NVMe Btrfs drive
  fileSystems."/mnt/nvme1tb" = {
    device = "/dev/disk/by-uuid/ff7b86e7-205e-4d67-96a0-719436935e7c";
    fsType = "btrfs";
    options = [ 
      "noatime"
      "nofail"
    ];
  };
}
