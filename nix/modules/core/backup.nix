{ config, lib, pkgs, ... }:
{
  fileSystems."/backup" = {
    device = "/dev/disk/by-label/backup";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  services.borgbackup.jobs =
    let
      common = {
        repo = "/backup/repo";
        doInit = true;
        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${config.sops.secrets.borg_passphrase.path}";
        };
        compression = "auto,zstd";
      };
      psql = config.services.postgresql.package;
    in {
      # db-* series: SQL dumps + SQLite snapshots, keep last 3
      db = common // {
        startAt = "03:00";
        paths = [ "/tmp/borg-db-dump" ];
        prune.keep.last = 3;
        preHook = ''
          install -dm 700 /tmp/borg-db-dump
          ${pkgs.util-linux}/bin/runuser -u postgres -- ${psql}/bin/pg_dump nextcloud > /tmp/borg-db-dump/nextcloud.sql
          ${pkgs.util-linux}/bin/runuser -u postgres -- ${psql}/bin/pg_dump immich    > /tmp/borg-db-dump/immich.sql
          cp /var/lib/directus/database.sqlite              /tmp/borg-db-dump/directus.sqlite
          cp ${config.services.grafana.dataDir}/grafana.db  /tmp/borg-db-dump/grafana.db
          cp /var/lib/jellyfin/data/jellyfin.db             /tmp/borg-db-dump/jellyfin.db
        '';
        postHook = "rm -rf /tmp/borg-db-dump";
      };

      # files-* series: user data + media + SSH host key, keep 7 daily
      files = common // {
        startAt = "04:00";
        paths = [
          config.services.nextcloud.datadir
          config.services.immich.mediaLocation
          "/var/lib/directus/uploads"
          "/var/lib/jellyfin"
          "/media"
          "/etc/ssh/ssh_host_ed25519_key"
        ];
        exclude = [
          # Immich: regeneratable from originals
          "${config.services.immich.mediaLocation}/upload/thumbs"
          "${config.services.immich.mediaLocation}/upload/encoded-video"
          # Jellyfin: downloaded metadata + cache are regeneratable
          "/var/lib/jellyfin/metadata"
          "/var/lib/jellyfin/cache"
        ];
        prune.keep.daily = 7;
      };
    };

  # Both jobs require the backup NVMe to be mounted first.
  # The borgbackup module does not auto-detect local mount dependencies.
  systemd.services."borgbackup-job-db".after       = [ "backup.mount" ];
  systemd.services."borgbackup-job-db".requires    = [ "backup.mount" ];
  systemd.services."borgbackup-job-files".after    = [ "backup.mount" ];
  systemd.services."borgbackup-job-files".requires = [ "backup.mount" ];
}
