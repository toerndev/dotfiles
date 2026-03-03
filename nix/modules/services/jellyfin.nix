{ config, pkgs, ... }:
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.jellyfin = {
    requires = [ "media.mount" ];
    after = [ "media.mount" ];
  };
}
