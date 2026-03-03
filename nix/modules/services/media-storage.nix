{ config, pkgs, ... }:
{
  fileSystems."/media" = {
    device = "/dev/disk/by-label/media";
    fsType = "ext4";
  };

  systemd.tmpfiles.rules = [
    "d /media/movies 0755 jellyfin jellyfin -"
    "d /media/tv 0755 jellyfin jellyfin -"
    "d /media/music 0755 jellyfin jellyfin -"
    "d /media/kids 0755 jellyfin jellyfin -"
  ];
}
