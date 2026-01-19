# ~/nixos-config/modules/desktop-hardware.nix
# This file contains the machine-specific hardware configuration for moonbeauty (Desktop).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # ====================================================================
  #  BOOT AND SYSTEM CONFIGURATION
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

    #VM stuff
  "amd_iommu=on"
  "iommu=pt"
  "vfio-pci.ids=1002:743f,1002:ab28" # RX 6400 Video and Audio IDs
  ];
  boot.initrd.kernelModules = [ 
    "amdgpu" 
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "vfio_pci" "vfio" "vfio_iommu_type1"];
  boot.kernelModules = [ "kvm-amd"  "i2c-dev" "i2c-piix4" "kvmfr" "vendor-reset"];
boot.extraModulePackages = with config.boot.kernelPackages; [
  kvmfr
  vendor-reset
];

boot.extraModprobeConfig = ''
  softdep amdgpu pre: vfio-pci vendor-reset

  options kvmfr static_size_mb=64
'';
virtualisation.libvirtd.qemu.verbatimConfig = ''
  cgroup_device_acl = [
      "/dev/null", "/dev/full", "/dev/zero",
      "/dev/random", "/dev/urandom",
      "/dev/ptmx", "/dev/kvm", "/dev/rtc",
      "/dev/hpet", "/dev/kvmfr0"
  ]
'';


#This is for the latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # ====================================================================
  #  FILE SYSTEM
  # ====================================================================
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/f427c3b9-0fd4-4868-bb33-8e1393be4201";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9FF9-E2A6";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp34s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp35s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
