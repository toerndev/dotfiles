{ config, pkgs, ... }:
{
  networking.networkmanager.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 8096 ];  # SSH + Jellyfin
  };
}
