{ config, lib, ... }:
{
  options.homelab.lanInterface = lib.mkOption {
    type = lib.types.str;
    example = "enp8s0";
    description = ''
      The NIC on the LAN (server: wired, htpc: Wi-Fi). Set per host from
      `ip -br link`; modules that open LAN ports use it.
    '';
  };

  config = {
    # One NIC per host. The router holds a DHCP reservation per MAC (server:
    # .70, which the router's port forwards point to; htpc: .71).
    networking.useNetworkd = true;
    networking.useDHCP = false; # overrides the mkDefault in hardware-configuration.nix
    networking.interfaces.${config.homelab.lanInterface} = {
      useDHCP = true;
      wakeOnLan.enable = lib.mkDefault true;
    };

    # networkd only manages links; resolved turns the DHCP-provided DNS into resolv.conf.
    services.resolved.enable = true;
  };
}
