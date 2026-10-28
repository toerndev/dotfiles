{ ... }:
{
  # Wired only: enp8s0 is cabled straight to the OpenWrt router, which holds a
  # DHCP reservation for this MAC → 192.168.1.70 (endlessh binds to that address).
  networking.useNetworkd = true;
  networking.useDHCP = false; # overrides the mkDefault in hardware-configuration.nix
  networking.interfaces.enp8s0 = {
    useDHCP = true;
    wakeOnLan.enable = true;
  };

  # networkd only manages links; resolved turns the DHCP-provided DNS into resolv.conf.
  services.resolved.enable = true;

  # Keep the Wi-Fi radio (MediaTek MT7921) fully off — no driver, no wlp7s0.
  boot.blacklistedKernelModules = [ "mt7921e" ];
}
