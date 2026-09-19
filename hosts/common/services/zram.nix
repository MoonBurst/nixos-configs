{ config, pkgs, ... }: {

  # 1. Fixes Kernel Memory Defragmentation Stutters
  boot.kernelParams = [ "transparent_hugepage=madvise" ];

  # 2. Ultra-Fast Zero-Overhead ZRAM Memory Pool
  zramSwap = {
    enable = true;
    algorithm = "lzo-rle";
    memoryPercent = 100;
  };

  # 3. Steam & Gaming Integration
  programs.steam.enable = true;
  programs.gamemode.enable = true;

  # 4. Low-Latency Kernel Memory Tuning
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;             # Uses free physical RAM first
    "vm.compaction_proactiveness" = 0; # Stops background RAM defrag daemon
    "vm.page-cluster" = 0;             # Single-page swapping for ZRAM
    "vm.watermark_boost_factor" = 0;   # Prevents CPU spikes during memory allocation
  };

  # 5. Disable Disk Swap
  swapDevices = [ ];
}
