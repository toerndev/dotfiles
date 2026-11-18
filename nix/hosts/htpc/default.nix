# The living-room box (Ryzen 8700G): Kodi, Steam, RetroArch.
{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/htpc
  ];

  networking.hostName = "htpc";

  # Wi-Fi only (MediaTek MT7921): iwd associates, networkd runs DHCP on it.
  # The NixOS iwd module keeps the kernel's name (wlan0), not udev's wlp7s0.
  # The router reserves .71 for this NIC's MAC. The passphrase lives only on
  # the box, in /var/lib/iwd/ (root, 600), never in this repo.
  homelab.lanInterface = "wlan0";
  networking.interfaces.${config.homelab.lanInterface}.wakeOnLan.enable = false;
  networking.wireless.iwd = {
    enable = true;
    settings = {
      General.EnableNetworkConfiguration = false; # networkd does DHCP
      Settings.AutoConnect = true;
    };
  };

  # The kernel the hardware config was generated on: its initrd lists
  # xhci_pci_prom21 (B650 USB), which the 26.05 default kernel lacks.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Not reachable from outside the LAN: the router forwards nothing here and
  # runs no UPnP, and this firewall admits only SSH from the LAN. Outgoing
  # traffic is unrestricted (Steam, YouTube).
  networking.firewall.interfaces.${config.homelab.lanInterface}.allowedTCPPorts = [ 22 ];

  # The release this host was installed with; never change it.
  system.stateVersion = "26.05";
}
