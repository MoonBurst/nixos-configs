{ pkgs, ... }:

{
  # 1. Official Auto Scrubbing (Checks for corruption)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  # 2. Custom Auto Balancing (Cleans up empty chunks)
  systemd.services.btrfs-balance = {
    description = "Btrfs balance to reclaim empty chunks";
    serviceConfig.Type = "oneshot";
    script = ''
      # List of all your Btrfs mount points from lsblk
      TARGETS=("/" "/mnt/3TBHDD" "/mnt/nvme1tb" "/mnt/main_backup")

      for target in "''${TARGETS[@]}"; do
        if [ -d "$target" ]; then
          echo "Starting balance on $target..."
          # -dusage=15: Data chunks less than 15% full
          # -musage=5: Metadata chunks less than 5% full
          ${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=15 -musage=5 "$target" || echo "Skipped $target (not a Btrfs mount or busy)"
        fi
      done
    '';
  };

  systemd.timers.btrfs-balance = {
    description = "Monthly Btrfs balance";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "monthly";
      Persistent = true;
    };
  };

  # 3. Essential Tools
  environment.systemPackages = with pkgs; [
    btrfs-progs
    compsize
  ];
}
