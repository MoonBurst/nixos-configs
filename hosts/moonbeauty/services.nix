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
          --vfs-write-back 5s \
          --dir-cache-time 5m \
          --attr-timeout 5m \
          --webdav-nextcloud-chunk-size 10M \
          --bwlimit 200k \
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
      extraCreateArgs = "--stats --list --filter=AME";
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
      extraCreateArgs = "--stats --list --filter=AME";
      prune.keep = { daily = 7; weekly = 4; monthly = 6; };
      exclude = baseExcludes ++ [ "*/stump_backup.tar.gz" ];
      encryption = {
        mode = "repokey-blake2";
        passCommand = "${pkgs.coreutils}/bin/cat ${config.sops.secrets.borg_passphrase.path}";
      };
    };
  };

  systemd.services."borgbackup-job-MoonBeauty-Offsite" = {
    bindsTo = [ "mount-nextcloud.service" ];
    after = [ "mount-nextcloud.service" ];
  };
}
