{ config, pkgs, lib, ... }:

let
  rcloneConfigPath = "/run/rclone-mount/nextcloud.conf";
  rcloneCacheDir = "/mnt/3TBHDD/rclone-cache";

  baseExcludes = [
    "*/.config/BraveSoftware"
    "*/.config/vivaldi"
    "*/.config/vesktop"
    "*/.cache"
    "*/.direnv"
    "**/node_modules"
    "**/.cargo"
    "**/.rustup"
    "**/.gradle"
    "*/.local/share/Steam"
    "*/.steam"
    "*/Games"
    "*/.librewolf"
    "*/.lmstudio"
    "*/.var"
    "*/.local/share/vicinae"
    "*/.local/share/pnpm"
    "*/.local/share/rustup"
    "*/.cache"
    "*/.cache/vivaldi"
    "*/.cache/mesa_shader_cache"
    "*/.cache/appimage-run"
    "*/.cache/mozilla/firefox"
    "*/.cache/google-chrome"
    "**/mesa_shader_cache_db"
    "**/radv_builtin_shaders"
    "*/.local/share/Trash"
    "*/.Trash*"
    "**/.tmp"
    "**/*.swp"
    "**/*.bak"
    "*/.config/sops"
  ];

  toFindArg = pattern:
    let
      cleaned = lib.replaceStrings [ "**/" ] [ "*/" ] pattern;
    in
    "-path '${cleaned}'";

  pruneExpr = lib.concatMapStringsSep " -o " toFindArg (baseExcludes ++ [ "*/stump_backup.tar.gz" ]);

  monitorScript = pkgs.writeShellScript "borg-monitor" ''
    TOTAL_FILES=0

    ${pkgs.systemd}/bin/journalctl -u borgbackup-job-MoonBeauty-Offsite.service -f -n 0 -o cat | while read -r line; do
      if [ "$TOTAL_FILES" -eq 0 ]; then
        TOTAL_FILES=$(${pkgs.coreutils}/bin/cat /dev/shm/borg-offsite-total.txt 2>/dev/null || echo 0)
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

        echo "{\"status\": \"running\", \"percent\": $PERCENT, \"processed_files\": $CURRENT_FILES, \"total_files\": $TOTAL_FILES, \"original_size\": \"$ORIG_SIZE\", \"uploaded_size\": \"$DEDUPL_SIZE\", \"text\": \"Backup: $PERCENT% ($DEDUPL_SIZE sent)\"}" > /dev/shm/borg-offsite-status.json
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

  systemd.services.mount-nextcloud = {
    description = "Mount Nextcloud for Borg";
    after = [ "network-online.target" "sops-install-secrets.service" ];
    wants = [ "network-online.target" "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "notify";
      RuntimeDirectory = "rclone-mount";
      ExecStartPre = lib.mkForce (pkgs.writeShellScript "prep-nextcloud-mount" ''
        export PATH=$PATH:${pkgs.glibc.bin}/bin
        ${pkgs.coreutils}/bin/mkdir -p /mnt/nextcloud
        ${pkgs.coreutils}/bin/mkdir -p ${rcloneCacheDir}

        RAW_URL=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.nextcloud_url.path} | ${pkgs.coreutils}/bin/tr -d '[:space:]')
        USER=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.nextcloud_user.path} | ${pkgs.coreutils}/bin/tr -d '[:space:]')
        PASS=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.nextcloud_pass.path} | ${pkgs.coreutils}/bin/tr -d '[:space:]')

        OBSCURED_PASS=$(${pkgs.rclone}/bin/rclone obscure "$PASS")

        BASE_URL=$(echo "$RAW_URL" | ${pkgs.gnused}/bin/sed 's|/*$||')
        FINAL_URL="$BASE_URL/remote.php/dav/files/$USER/"

        echo "[NextCloud]
        type = webdav
        vendor = nextcloud
        url = $FINAL_URL
        user = $USER
        pass = $OBSCURED_PASS" > ${rcloneConfigPath}
        ${pkgs.coreutils}/bin/chmod 600 ${rcloneConfigPath}
      '');

      ExecStart = lib.mkForce ''
        ${pkgs.rclone}/bin/rclone mount NextCloud: /mnt/nextcloud \
          --config ${rcloneConfigPath} \
          --cache-dir ${rcloneCacheDir} \
          --vfs-cache-mode full \
          --vfs-cache-max-size 100G \
          --vfs-cache-max-age 24h \
          --vfs-write-back 5s \
          --dir-cache-time 5m \
          --attr-timeout 1m \
          --webdav-nextcloud-chunk-size 5M \
          --transfers 2 \
          --low-level-retries 10 \
          --retries 5 \
          --timeout 5m \
          --contimeout 2m \
          --allow-non-empty \
          --allow-other \
          --rc \
          --stats 5s
      '';

      ExecStop = lib.mkForce "${pkgs.fuse}/bin/fusermount -uz /mnt/nextcloud";
      Restart = "on-failure";
    };
  };

  services.borgbackup.jobs = {
    "MoonBeauty-Local" = {
      paths = [ "/home/moonburst" ];
      repo = "/mnt/main_backup";
      startAt = "00:00";
      doInit = true;
      compression = "zstd,6";
      extraCreateArgs = "--stats --list --filter=AME --progress";
      prune.keep = { daily = 7; weekly = 4; monthly = 6; };
      exclude = baseExcludes;
      encryption = {
        mode = "repokey-blake2";
        passCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.borg_passphrase.path}";
      };
    };

    "MoonBeauty-Offsite" = {
      paths = [ "/home/moonburst" ];
      repo = "/mnt/nextcloud";
      startAt = "02:00";
      doInit = true;
      compression = "zstd,6";
      extraCreateArgs = "--stats --list --filter=AME --checkpoint-interval 300 --progress";
      prune.keep = { daily = 7; weekly = 4; monthly = 6; };
      exclude = baseExcludes ++ [
        "*/stump_backup.tar.gz"
        "*/soh-windows 2.zip"
      ];
      encryption = {
        mode = "repokey-blake2";
        passCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.borg_passphrase.path}";
      };

      preHook = ''
        echo '{"status": "indexing", "percent": 0, "text": "Indexing..."}' > /dev/shm/borg-offsite-status.json

        TOTAL_FILES=$(${pkgs.findutils}/bin/find /home/moonburst \( ${pruneExpr} \) -prune -o -type f -print | ${pkgs.coreutils}/bin/wc -l)
        echo "$TOTAL_FILES" > /dev/shm/borg-offsite-total.txt
      '';

      postHook = ''
        echo '{"status": "syncing", "percent": 100, "text": "Uploading to cloud..."}' > /dev/shm/borg-offsite-status.json

        while true; do
          STATS=$(${pkgs.rclone}/bin/rclone rc core/stats --url http://localhost:5572 2>/dev/null)
          if [ -z "$STATS" ]; then
            break
          fi

          ACTIVE_TRANSFERS=$(echo "$STATS" | ${pkgs.jq}/bin/jq '.transferring | length' 2>/dev/null || echo 0)
          if [ "$ACTIVE_TRANSFERS" -eq 0 ]; then
            break
          fi

          RAW_SPEED=$(echo "$STATS" | ${pkgs.jq}/bin/jq -r '.speed // 0' 2>/dev/null)
          RAW_BYTES=$(echo "$STATS" | ${pkgs.jq}/bin/jq -r '.bytes // 0' 2>/dev/null)
          RAW_TOTAL=$(echo "$STATS" | ${pkgs.jq}/bin/jq -r '.totalBytes // 0' 2>/dev/null)
          RAW_ETA=$(echo "$STATS" | ${pkgs.jq}/bin/jq -r '.eta // 0' 2>/dev/null)

          SPEED=''${RAW_SPEED%.*}
          BYTES=''${RAW_BYTES%.*}
          TOTAL=''${RAW_TOTAL%.*}
          ETA=''${RAW_ETA%.*}

          if [ -z "$SPEED" ]; then
            SPEED=0
          fi
          if [ -z "$BYTES" ]; then
            BYTES=0
          fi
          if [ -z "$TOTAL" ]; then
            TOTAL=0
          fi
          if [ -z "$ETA" ]; then
            ETA=0
          fi

          if [ "$TOTAL" -gt 0 ]; then
            PERCENT=$(( BYTES * 100 / TOTAL ))
            REMAINING=$(( TOTAL - BYTES ))
            if [ "$REMAINING" -lt 0 ]; then
              REMAINING=0
            fi
          else
            PERCENT=0
            REMAINING=0
          fi

          BYTES_MB=$(( BYTES / 1048576 ))
          TOTAL_MB=$(( TOTAL / 1048576 ))
          REMAINING_MB=$(( REMAINING / 1048576 ))
          SPEED_KBS=$(( SPEED / 1024 ))

          if [ "$SPEED_KBS" -ge 1024 ]; then
            SPEED_DISPLAY="$(( SPEED_KBS / 1024 )) MB/s"
          else
            SPEED_DISPLAY="''${SPEED_KBS} KB/s"
          fi

          if [ "$ETA" -gt 0 ]; then
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

          echo "{\"status\": \"syncing\", \"percent\": $PERCENT, \"uploaded_size\": \"''${BYTES_MB} MB\", \"total_size\": \"''${TOTAL_MB} MB\", \"remaining_size\": \"''${REMAINING_MB} MB\", \"speed\": \"''${SPEED_DISPLAY}\", \"eta\": \"''${ETA_DISPLAY}\"}" > /dev/shm/borg-offsite-status.json

          sleep 3
        done

        echo '{"status": "idle", "percent": 100, "text": "Idle"}' > /dev/shm/borg-offsite-status.json
        rm -f /dev/shm/borg-offsite-total.txt
      '';
    };
  };

  systemd.services."borgbackup-job-MoonBeauty-Offsite" = {
    bindsTo = [ "mount-nextcloud.service" ];
    after = [ "mount-nextcloud.service" ];

    postStart = "${monitorScript} &";
  };
}
