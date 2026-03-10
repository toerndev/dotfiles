{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/services
  ];

  networking.hostName = "htpc";
}
