{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/services
  ];

  networking.hostName = "htpc";

  users.motd = "deploy-rs: it works\n";
}
