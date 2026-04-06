{ config, pkgs, ... }: {

  # 1. Define the custom systemd service
  systemd.services.custom-zram = {
    description = "Custom zram initialization service";

    # Ensure it starts early during boot
    wantedBy = [ "multi-user.target" ];
    after = [ "dev-zram0.device" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # The actual commands to set up the device
    script = ''
      # Load the module
      ${pkgs.kmod}/bin/modprobe zram

      # Reset and set algorithm/size
      echo 1 > /sys/block/zram0/reset || true
      echo zstd > /sys/block/zram0/comp_algorithm
      echo 4G > /sys/block/zram0/disksize # Set your desired compressed size

      # Initialize as swap and enable
      ${pkgs.util-linux}/bin/mkswap /dev/zram0
      ${pkgs.util-linux}/bin/swapon /dev/zram0 --priority 100
    '';

    # Clean up when service stops
    preStop = ''
      ${pkgs.util-linux}/bin/swapoff /dev/zram0 || true
      echo 1 > /sys/block/zram0/reset
    '';
  };

  # 2. Add required tools to system path
  environment.systemPackages = with pkgs; [
    util-linux # for mkswap/swapon
    zram-tools # for zramctl
  ];
}
