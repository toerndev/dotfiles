{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = "/etc/secrets/wg-private-key";
    mtu = 1280;
    peers = [
      { publicKey = "+9mageJp5UeDEDmj+EGw1inwy5BpMED0OjVu/tYF6U0="; allowedIPs = [ "10.100.0.2/32" ]; }  # Home laptop
      { publicKey = "k/A2D/QJE56P2gCF7iJi0LhOY8liZJ5jtorTiX/poB4="; allowedIPs = [ "10.100.0.3/32" ]; }  # Work laptop
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];
}
