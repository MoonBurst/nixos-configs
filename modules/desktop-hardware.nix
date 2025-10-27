# ~/nixos-config/modules/desktop-hardware.nix
{ config, pkgs, ... }:

{
  # ====================================================================
  # BOOT AND SYSTEM CONFIGURATION (Hardware Specific)
  # ====================================================================

  # Bootloader (systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- AMDGPU/ROCm Kernel Parameters ---
  boot.kernelParams = [
    "amdgpu.vm_fragment_size=9"
    "fbcon=rotate:2" #--rotates screen
    "amdgpu.ppfeaturemask=0xffffffff" #--needed for corectrl
    "cma=512M"
  ];

  boot.initrd.kernelModules = [ 
    "amdgpu" 
  ];

  # ====================================================================
  # FILE SYSTEM CONFIGURATION (MANDATORY)
  # ====================================================================
  fileSystems."/" = {
    # UUID of /dev/nvme1n1p1 (Root Partition)
    device = "/dev/disk/by-uuid/f427c3b9-0fd4-4868-bb33-8e1393be4201"; 
    fsType = "btrfs"; 
    # Uncomment and update subvolume if you use one (e.g., options = [ "subvol=@root" ];)
    # options = [ "subvol=root" ]; 
  };

  fileSystems."/boot" = {
    # UUID of /dev/nvme1n1p2 (EFI System Partition)
    device = "/dev/disk/by-uuid/9FF9-E2A6";
    fsType = "vfat";
  };

  # If you want to mount your 3TB HDD permanently
  fileSystems."/mnt/3tb-hdd" = {
    device = "/dev/disk/by-uuid/2771f69c-effd-4d1d-afd3-8940399ae700";
    fsType = "btrfs";
    # options = [ "subvol=data" ]; # Add relevant options
  };

}
