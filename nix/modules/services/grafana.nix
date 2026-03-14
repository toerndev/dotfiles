{ ... }:
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        root_url = "http://10.100.0.1/grafana";
        serve_from_sub_path = true;
      };

      analytics.reporting_enabled = false;
    };

    provision.datasources.settings.datasources = [
      {
        name = "Loki";
        type = "loki";
        url = "http://localhost:3100";
        isDefault = true;
      }
    ];
  };

  # Sandbox grafana loopback access — allow responses to incoming connections
  # (Caddy reverse proxy) and outbound to Loki only.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 3100 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 3100 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -j REJECT || true
  '';
}
