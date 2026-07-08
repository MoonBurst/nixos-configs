{ config, pkgs, lib, ... }: {
  
  # libvirtd and guest VM management engines
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Looking Glass shared memory configuration
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 moonburst libvirtd -"
  ];

  # GPU Passthrough / Virtual Framebuffer Permissions
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
  '';

  # Specialized PCI Reset & Virtual Buffer Kernel Modules
  boot.kernelModules = [ "kvmfr" "vendor-reset" ];
  
  boot.extraModulePackages = with config.boot.kernelPackages; [ 
    vendor-reset 
  ];

  # PCI Subsystem Priority Probes & Setup
  boot.extraModprobeConfig = ''
    options kvmfr static_size_mb=128
    softdep AMDGPU pre: vendor-reset
  '';

  # IOMMU hypervisor kernel command lines (Commented as your baseline defaults)
  boot.kernelParams = [
    # "amd_iommu=on"
    # "iommu=pt"
    # "vfio-pci.ids=1002:743f,1002:ab28"
  ];
}
