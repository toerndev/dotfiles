{ pkgs, config, ... }:
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = 51820;
    privateKeyFile = config.sops.secrets.wireguard_private_key.path;
    mtu = 1280;
    peers = [
      { publicKey = "+9mageJp5UeDEDmj+EGw1inwy5BpMED0OjVu/tYF6U0="; allowedIPs = [ "10.100.0.2/32" ]; }  # Home laptop
      { publicKey = "k/A2D/QJE56P2gCF7iJi0LhOY8liZJ5jtorTiX/poB4="; allowedIPs = [ "10.100.0.3/32" ]; }  # Work laptop
      { publicKey = "FawxhkgRS02QKDbbCmlJ+mZZLIsKiZwOz9mYXNmh3io="; allowedIPs = [ "10.100.0.4/32" ]; } # Android phone
    ];
  };

  networking.firewall.allowedUDPPorts = [ 51820 ];

  # Vite dev server - WG only, no Caddy involvement.
  # Bind with: vite --host 10.100.0.1
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 5173 ];
}
