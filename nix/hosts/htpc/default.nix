# The living-room box (Ryzen 8700G): Kodi, Steam, RetroArch.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/htpc
  ];

  networking.hostName = "htpc";

  homelab.lanInterface = "enp8s0";

  # Keep the Wi-Fi radio (MediaTek MT7921) fully off: no driver, no wlp7s0.
  boot.blacklistedKernelModules = [ "mt7921e" ];

  # No WireGuard here: sshd on the LAN. Reach it from outside through the
  # server (`ssh -J losipai@10.100.0.1 losipai@192.168.1.71`).
  networking.firewall.interfaces.enp8s0.allowedTCPPorts = [ 22 ];

  # The release this host was installed with; never change it. 24.11 and the
  # hardware config are the old install's: replace both when installing.
  system.stateVersion = "24.11";
}
