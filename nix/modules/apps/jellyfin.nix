{ config, pkgs, ... }:
{
  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };

  # LAN for playback clients, WG for administration via Homepage.
  networking.firewall.interfaces.wlp7s0.allowedTCPPorts = [ 8096 ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 8096 ];

  systemd.services.jellyfin = {
    requires = [ "media.mount" ];
    after = [ "media.mount" ];
  };
}
