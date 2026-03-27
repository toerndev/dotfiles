{ config, ... }:
{
  services.immich = {
    enable = true;

    # Bind to loopback; Caddy proxies from the WireGuard vhost.
    host = "127.0.0.1";

    # Store originals on the large media partition.
    # Directory is created below via tmpfiles.
    mediaLocation = "/media/immich";

    # database.enable and redis.enable default to true. The module creates
    # services.postgresql and services.redis.servers.immich automatically and
    # shares the same PostgreSQL instance as Nextcloud (separate databases).
    # database.enableVectorChord defaults to true for stateVersion >= 25.11.

    # machine-learning.enable defaults to true, runs the ML worker locally.

    # settings = null: allow configuration via the admin web UI.
  };

  # Create the media directory on the large partition.
  # systemd-tmpfiles.setup runs after local-fs.target, so /media is mounted.
  systemd.tmpfiles.rules = [
    "d /media/immich 0750 immich immich -"
  ];

  # Expose Immich on the WireGuard interface only via Caddy.
  # Android client connects via WireGuard tunnel; no public exposure.
  services.caddy.virtualHosts."http://10.100.0.1:2283" = {
    listenAddresses = [ "10.100.0.1" ];
    extraConfig = ''
      reverse_proxy localhost:2283

      log {
        output file /var/log/caddy/access-immich.log {
          mode 0640
        }
        format json
      }
    '';
  };

  # Open port 2283 on the WireGuard interface only.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 2283 ];

  # Allow Caddy to reach the Immich server on loopback.
  # Sandbox Immich loopback access: allow replies to Caddy (ESTABLISHED),
  # outbound to the ML worker (port 3003), reject everything else.
  # Redis and PostgreSQL use unix sockets so are unaffected by these rules.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 2283 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner immich -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner immich -o lo -p tcp --dport 3003 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner immich -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 2283 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner immich -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner immich -o lo -p tcp --dport 3003 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner immich -o lo -j REJECT || true
  '';
}
