{ config, pkgs, ... }: {

  systemd.services.zram = {
    description = "Dynamic 50% RAM zram Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "dev-zram0.device" ];

    path = with pkgs; [
      gawk
      gnugrep
      kmod
      util-linux
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
#Load the module
      modprobe zram

#Reset the device
      echo 1 > /sys/block/zram0/reset || true

#Calculate 50% of Total RAM dynamically
      TOTAL_K=$(grep MemTotal /proc/meminfo | awk '{print $2}')
      ZRAM_SIZE=$((TOTAL_K / 2))"K"

#Set the dynamic size and algorithm
      echo zstd > /sys/block/zram0/comp_algorithm
      echo $ZRAM_SIZE > /sys/block/zram0/disksize

#Disable all other swap (ensures disk is never used)
      swapoff -a || true

#Activate zram
      mkswap /dev/zram0
      swapon /dev/zram0 --priority 100
    '';

    preStop = ''
      swapoff /dev/zram0 || true
      echo 1 > /sys/block/zram0/reset
    '';
  };

  # Kernel tweaks to prioritize RAM over disk
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 500;
  };

  environment.systemPackages = [ pkgs.util-linux ];
  swapDevices = [ ];
}
