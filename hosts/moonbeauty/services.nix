{ config, pkgs, lib, ... }:

let
  rcloneConfigPath = "/run/rclone-mount/nextcloud.conf";
  rcloneCacheDir = "/mnt/3TBHDD/rclone-cache";

  baseExcludes = [
    "*/.config/BraveSoftware"
    "*/.cache/BraveSoftware"
    "*/.cache/nix"
    "*/.cache/nix-data"
    "*/.cache/nix-index"
    "*/.cache/nix.bak"
    "*/.direnv"
    "**/node_modules"
    "**/.cargo"
    "**/.rustup"
    "**/.gradle"
    "*/.local/share/Steam"
    "*/.steam"
    "*/Games"
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
      Type = "simple";
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
          --vfs-write-back 2m \
          --dir-cache-time 1m \
          --attr-timeout 1m \
          --webdav-nextcloud-chunk-size 1M \
          --bwlimit 100k \
          --transfers 1 \
          --tpslimit 0.5 \
          --low-level-retries 20 \
          --retries 10 \
          --timeout 30m \
          --contimeout 30m \
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
      exclude = baseExcludes ++ [ "*/stump_backup.tar.gz" ];
      encryption = {
        mode = "repokey-blake2";
        passCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.borg_passphrase.path}";
      };

      # Set initial status on shared storage media (/dev/shm)
      preHook = ''
        echo '{"status": "indexing", "percent": 0, "text": "Indexing..."}' > /dev/shm/borg-offsite-status.json

        EXCLUDE_ARGS=""
        ${lib.concatMapStringsSep "\n" (pattern: ''
          EXCLUDE_ARGS="$EXCLUDE_ARGS -not -path '${pattern}'"
        '') (baseExcludes ++ [ "*/stump_backup.tar.gz" ])}

        TOTAL_FILES=$(eval "${pkgs.findutils}/bin/find /home/moonburst -type f $EXCLUDE_ARGS | ${pkgs.coreutils}/bin/wc -l")
        echo "$TOTAL_FILES" > /dev/shm/borg-offsite-total.txt
      '';

      postHook = ''
        echo '{"status": "idle", "percent": 100, "text": "Idle"}' > /dev/shm/borg-offsite-status.json
        rm -f /dev/shm/borg-offsite-total.txt
      '';
    };
  };

  # Use systemd logging parameters cleanly without complex process sub-shells
  systemd.services."borgbackup-job-MoonBeauty-Offsite" = {
    bindsTo = [ "mount-nextcloud.service" ];
    after = [ "mount-nextcloud.service" ];

    # Intercept systemd's local runtime stdout/stderr log engines asynchronously
    postStart = ''
      ${pkgs.bash}/bin/bash -c '
        TOTAL_FILES=$(${pkgs.coreutils}/bin/cat /dev/shm/borg-offsite-total.txt 2>/dev/null || echo 0)

        ${pkgs.systemd}/bin/journalctl -u borgbackup-job-MoonBeauty-Offsite.service -f -n 0 -o cat | while read -r line; do
          # Enhanced regex pattern explicitly matching metric counters
          if [[ "$line" =~ ([0-9.]+\ +[KMG]?B\ +O)\ +([0-9.]+\ +[KMG]?B\ +C)\ +([0-9.]+\ +[KMG]?B\ +D)\ +([0-9]+) ]]; then
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
      ' &
    '';
  };
}
