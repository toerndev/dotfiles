{ config, pkgs, ... }:
{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;
    editor = false;
  };
  boot.loader.timeout = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "ntfs" ];
}
