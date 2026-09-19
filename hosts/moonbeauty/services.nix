{ config, pkgs, lib, ... }:

let
  rcloneConfigPath = "/run/rclone/nextcloud.conf";

  baseExcludes = [
    "*/.config/BraveSoftware"
    "*/.config/vivaldi"
    "*/.config/vesktop"
    "*/.config/sops"
    "*/.cache"
    "*/.direnv"
    "**/node_modules"
    "**/.cargo"
    "**/.rustup"
    "**/.gradle"
    "*/.local/share"
    "*/.steam"
    "*/Games"
    "*/.librewolf"
    "*/.lmstudio"
    "*/.var"
    "*/Documents/image_gen"
    "*/Projects"
    "*/.Trash*"
    "**/.tmp"
    "**/*.swp"
    "**/*.bak"
    "*/stump_backup.tar.gz"
    "*/soh-windows 2.zip"
  ];

  toFindArg = pattern:
    let
      cleaned = lib.replaceStrings [ "**/" ] [ "*/" ] pattern;
    in
    "-path '${cleaned}'";

  pruneExpr = lib.concatMapStringsSep " -o " toFindArg baseExcludes;

  monitorScript = pkgs.writeShellScript "borg-monitor" ''
    TOTAL_FILES=0

    ${pkgs.systemd}/bin/journalctl -u borgbackup-job-MoonBeauty-Local.service -f -n 0 -o cat | while read -r line; do
      if [ "$TOTAL_FILES" -eq 0 ]; then
        TOTAL_FILES=$(${pkgs.coreutils}/bin/cat /dev/shm/borg-backup-total.txt 2>/dev/null || echo 0)
      fi

      if [[ "$line" =~ ([0-9.]+[[:space:]]+[kKmMgGtT]?B[[:space:]]+O)[[:space:]]+([0-9.]+[[:space:]]+[kKmMgGtT]?B[[:space:]]+C)[[:space:]]+([0-9.]+[[:space:]]+[kKmMgGtT]?B[[:space:]]+D)[[:space:]]+([0-9]+) ]]; then
        ORIG_SIZE="''${BASH_REMATCH[1]}"
        DEDUPL_SIZE="''${BASH_REMATCH[3]}"
        CURRENT_FILES="''${BASH_REMATCH[4]}"

        if [ "$TOTAL_FILES" -gt 0 ]; then
          PERCENT=$(( CURRENT_FILES * 100 / TOTAL_FILES ))
          [ "$PERCENT" -gt 100 ] && PERCENT=100
        else
          PERCENT=0
        fi

        echo "{\"status\": \"running\", \"percent\": $PERCENT, \"processed_files\": $CURRENT_FILES, \"total_files\": $TOTAL_FILES, \"original_size\": \"$ORIG_SIZE\", \"uploaded_size\": \"$DEDUPL_SIZE\", \"text\": \"Local Backup: $PERCENT% ($DEDUPL_SIZE written)\"}" > /dev/shm/borg-offsite-status.json
      fi
    done
  '';
in
{
  sops.defaultSopsFile = ../../secrets.yaml;

  sops.secrets = {
    moonburst_password = {};
    borg_passphrase = {};
    nextcloud_url = {};
    nextcloud_user = {};
    nextcloud_pass = {};
  };

  # 1. Main Borg Backup Job (Scheduled Daily at 9:00 AM)
  services.borgbackup.jobs = {
    "MoonBeauty-Local" = {
      paths = [ "/home/moonburst" ];
      repo = "/mnt/main_backup";
      startAt = "09:00";
      doInit = true;
      compression = "zstd,6";
      extraCreateArgs = "--stats --list --filter=AME --checkpoint-interval 300 --progress";

      prune.keep = { daily = 7; weekly = 4; monthly = 6; };
      extraPruneArgs = "--stats";

      exclude = baseExcludes;
      encryption = {
        mode = "repokey-blake2";
        passCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.borg_passphrase.path}";
      };

      preHook = ''
        echo '{"status": "indexing", "percent": 0, "text": "Indexing files..."}' > /dev/shm/borg-offsite-status.json
        TOTAL_FILES=$(${pkgs.findutils}/bin/find /home/moonburst \( ${pruneExpr} \) -prune -o -type f -print | ${pkgs.coreutils}/bin/wc -l)
        echo "$TOTAL_FILES" > /dev/shm/borg-backup-total.txt
      '';

      postHook = ''
        rm -f /dev/shm/borg-backup-total.txt

        # Compact unused segments immediately after pruning
        export BORG_PASSPHRASE=$(cat ${config.sops.secrets.borg_passphrase.path})
        ${pkgs.borgbackup}/bin/borg compact /mnt/main_backup || true

        echo '{"status": "starting-sync", "percent": 100, "text": "Starting Cloud Sync..."}' > /dev/shm/borg-offsite-status.json
        ${pkgs.systemd}/bin/systemctl start sync-backup-to-nextcloud.service
      '';
    };
  };

  systemd.services."borgbackup-job-MoonBeauty-Local" = {
    postStart = "${monitorScript} &";
  };

  # 2. Offsite Nextcloud Sync Service
  systemd.services.sync-backup-to-nextcloud = {
    description = "Sync Local Borg Backup to Nextcloud WebDAV";
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wants = [ "network-online.target" "sops-install-secrets.service" ];
    path = [
      pkgs.glibc.bin
      pkgs.coreutils
      pkgs.gnused
      pkgs.gawk
      pkgs.jq
      pkgs.rclone
      pkgs.libnotify
    ];

    serviceConfig = {
      Type = "oneshot";
      KillMode = "control-group";
      RuntimeDirectory = "rclone";
      ExecStart = pkgs.writeShellScript "sync-nextcloud" ''
        export HOME="/run/rclone"

        USER_ID=$(id -u moonburst 2>/dev/null || echo 1000)
        send_notify() {
          sudo -u moonburst DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
            notify-send -a "Borg Backup" "$1" "$2" -i "$3" 2>/dev/null || true
        }

        RAW_URL=$(cat ${config.sops.secrets.nextcloud_url.path} | tr -d '[:space:]')
        USER=$(cat ${config.sops.secrets.nextcloud_user.path} | tr -d '[:space:]')
        PASS=$(cat ${config.sops.secrets.nextcloud_pass.path} | tr -d '[:space:]')

        OBSCURED_PASS=$(rclone obscure "$PASS")
        BASE_URL=$(echo "$RAW_URL" | sed 's|/*$||')
        FINAL_URL="$BASE_URL/remote.php/dav/files/$USER/"

        cat <<EOF > ${rcloneConfigPath}
[NextCloud]
type = webdav
vendor = nextcloud
url = $FINAL_URL
user = $USER
pass = $OBSCURED_PASS
EOF
        chmod 600 ${rcloneConfigPath}

        rclone sync /mnt/main_backup NextCloud:/Backups/BorgRepo \
          --config ${rcloneConfigPath} \
          --webdav-nextcloud-chunk-size 10M \
          --transfers 3 \
          --checkers 8 \
          --buffer-size 16M \
          --use-mmap \
          --timeout 60s \
          --contimeout 30s \
          --low-level-retries 10 \
          --retries 5 \
          --stats 5s \
          --verbose \
          --rc \
          --rc-addr localhost:5572 \
          --rc-no-auth &
        RCLONE_PID=$!

        while kill -0 $RCLONE_PID 2>/dev/null; do
          STATS=$(rclone rc core/stats --url http://localhost:5572 2>/dev/null)
          if [ -n "$STATS" ]; then
            BYTES=$(echo "$STATS" | jq -r '.bytes // 0')
            TOTAL=$(echo "$STATS" | jq -r '.totalBytes // 0')
            RAW_SPEED=$(echo "$STATS" | jq -r '.speed // 0')
            ETA=$(echo "$STATS" | jq -r '.eta // 0')

            SPEED_MB=$(awk "BEGIN {printf \"%.2f\", $RAW_SPEED / 1048576}")
            BYTES_MB=$(awk "BEGIN {printf \"%.0f\", $BYTES / 1048576}")
            TOTAL_MB=$(awk "BEGIN {printf \"%.0f\", $TOTAL / 1048576}")

            if [ "$TOTAL" -gt 0 ] 2>/dev/null; then
              PERCENT=$(awk "BEGIN {printf \"%.0f\", ($BYTES * 100) / $TOTAL}")
            else
              PERCENT=0
            fi

            if [ "$ETA" -gt 0 ] 2>/dev/null; then
              if [ "$ETA" -ge 3600 ]; then
                ETA_DISPLAY="$(( ETA / 3600 ))h $(( (ETA % 3600) / 60 ))m"
              elif [ "$ETA" -ge 60 ]; then
                ETA_DISPLAY="$(( ETA / 60 ))m $(( ETA % 60 ))s"
              else
                ETA_DISPLAY="''${ETA}s"
              fi
            else
              ETA_DISPLAY="Calculating..."
            fi

            echo "{\"status\": \"syncing\", \"percent\": $PERCENT, \"uploaded_size\": \"''${BYTES_MB} MB\", \"total_size\": \"''${TOTAL_MB} MB\", \"speed\": \"''${SPEED_MB} MB/s\", \"eta\": \"''${ETA_DISPLAY}\", \"text\": \"Uploading: $PERCENT% (''${SPEED_MB} MB/s)\"}" > /dev/shm/borg-offsite-status.json
          fi
          sleep 3
        done

        wait $RCLONE_PID
        SYNC_EXIT=$?

        if [ "$SYNC_EXIT" -eq 0 ]; then
          echo '{"status": "idle", "percent": 100, "text": "Idle"}' > /dev/shm/borg-offsite-status.json
          send_notify "Backup & Cloud Sync Complete" "All archives synced to Nextcloud cleanly." "drive-harddisk"
        else
          echo '{"status": "failed", "percent": 0, "text": "Sync Failed"}' > /dev/shm/borg-offsite-status.json
          send_notify "Cloud Sync Failed" "rclone exited with status $SYNC_EXIT. Check journalctl." "dialog-error"
        fi
      '';
    };
  };

  # 3. Dedicated Helper Scripts for Quickshell
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "game-sync-pause" ''
      ${pkgs.systemd}/bin/systemctl kill -s SIGKILL sync-backup-to-nextcloud.service 2>/dev/null || true
      ${pkgs.systemd}/bin/systemctl stop sync-backup-to-nextcloud.service 2>/dev/null || true
      ${pkgs.procps}/bin/pkill -9 -f 'rclone sync' 2>/dev/null || true
      ${pkgs.systemd}/bin/systemctl reset-failed sync-backup-to-nextcloud.service 2>/dev/null || true
    '')
    (pkgs.writeShellScriptBin "game-sync-resume" ''
      ${pkgs.systemd}/bin/systemctl start sync-backup-to-nextcloud.service
    '')
    (pkgs.writeShellScriptBin "borg-mount-browser" ''
      export BORG_PASSPHRASE=$(cat ${config.sops.secrets.borg_passphrase.path})
      ${pkgs.coreutils}/bin/mkdir -p /tmp/borg-mount
      ${pkgs.borgbackup}/bin/borg mount -o allow_other /mnt/main_backup /tmp/borg-mount
    '')
    (pkgs.writeShellScriptBin "borg-umount-browser" ''
      ${pkgs.borgbackup}/bin/borg umount /tmp/borg-mount 2>/dev/null || ${pkgs.fuse}/bin/fusermount -uz /tmp/borg-mount 2>/dev/null || true
    '')
  ];

  # 4. Sudo Rules for Borg Backup Controls & Helpers
  security.sudo.extraRules = [
    {
      users = [ "moonburst" ];
      commands = [
        # Helper Scripts (Game Pausing, Resuming, Mounting)
        {
          command = "/run/current-system/sw/bin/game-sync-pause";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/game-sync-resume";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/borg-mount-browser";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/borg-umount-browser";
          options = [ "NOPASSWD" ];
        }

        # Backup Sync Service Direct Control
        {
          command = "/run/current-system/sw/bin/systemctl start sync-backup-to-nextcloud.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop sync-backup-to-nextcloud.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl restart sync-backup-to-nextcloud.service";
          options = [ "NOPASSWD" ];
        }

        # Systemctl Maintenance
        {
          command = "/run/current-system/sw/bin/systemctl reset-failed";
          options = [ "NOPASSWD" ];
        }

        # Garbage Collection
        {
          command = "/run/current-system/sw/bin/nix-collect-garbage";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
