{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/secrets/wg-private-key";
    peers = [
      { publicKey = "+9mageJp5UeDEDmj+EGw1inwy5BpMED0OjVu/tYF6U0="; allowedIPs = [ "10.100.0.2/32" ]; }  # Laptop
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];
}
