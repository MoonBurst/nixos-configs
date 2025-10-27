# ~/nixos-config/modules/laptop-hardware.nix
{ config, lib, pkgs, ... }:

{
# ----------------------------------------------------------------------
# BOOTLOADER CONFIGURATION (Mandatory for EFI/Systemd-boot)
# ----------------------------------------------------------------------
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
# >>> CRITICAL SAFE DEPLOYMENT METHOD <<<
#boot.loader.grub.extraInit = ''
#boot.extraInitrdText = '' 
boot.initrd.extraText = ''
 # This command forces the new configuration to be switched during boot
  # It will be disabled immediately after the successful switch.
  ${config.system.build.toplevel}/bin/switch-to-configuration boot

  # Now, comment out 'boot.loader.grub.extraInit' in the config
  # and rebuild/reboot to remove this line from the boot script.
'';
# >>> CRITICAL SAFE DEPLOYMENT METHOD <<<
  # ====================================================================
  # KERNEL MODULES AND BOOT SETTINGS
  # ====================================================================

  # Modules needed at the start of the boot process
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "sd_mod" "rtsx_pci_sdmmc" ];

  # Modules loaded later
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ====================================================================
  # FILE SYSTEM CONFIGURATION (MANDATORY)
  # ====================================================================
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e82e50b3-9028-4549-887a-20f91058468c";
      fsType = "btrfs";
      # IMPORTANT: Your root uses a subvolume named "@"
      options = [ "subvol=@" "noatime" "compress=zstd"];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/A9BC-2F13";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/home/moonburst/usb" =
    { device = "/dev/sdb1";
      fsType = "exfat";
      # Note: If this is a temporary mount, you may want to remove this line later
    };

  swapDevices = [ ]; # Your system has no swap partition defined

  # ====================================================================
  # NETWORKING/SYSTEM
  # ====================================================================
  # These typically stay in the main host file, but can be here for simplicity
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
