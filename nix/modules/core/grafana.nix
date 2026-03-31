{ pkgs, ... }:
let
  # Dashboard 15156 uses ${DS_PROMETHEUS} as datasource UID. Substitute with
  # the explicit UID declared in the Prometheus datasource below.
  # Use builtins.replaceStrings to avoid sed regex escaping issues with ${...}.
  endlesshDashboards = pkgs.writeTextDir "endlessh-go.json" (
    builtins.replaceStrings
      [ ("$" + "{DS_PROMETHEUS}") ]
      [ "prometheus" ]
      (builtins.readFile (pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/15156/revisions/16/download";
        hash = "sha256-tM0qk1XieK7hkIY8llV8aozdq6zsqcrZ6+6d7u9njGQ=";
      }))
  );

  # Dashboard 19010 (CrowdSec Overview) uses ${DS_PROMETHEUS} — same substitution
  # pattern as the endlessh-go dashboard.
  crowdsecDashboards = pkgs.writeTextDir "crowdsec.json" (
    builtins.replaceStrings
      [ ("$" + "{DS_PROMETHEUS}") ]
      [ "prometheus" ]
      (builtins.readFile (pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/19010/revisions/1/download";
        hash = "sha256-REXluCzUYoueiOy3b6RPbbLCEet94+a/UfoU6OE9F40=";
      }))
  );
in
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
        uid = "loki";
      }
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        uid = "prometheus";
      }
    ];

    provision.dashboards.settings.providers = [
      {
        name = "endlessh-go";
        options.path = endlesshDashboards;
      }
      {
        name = "crowdsec";
        options.path = crowdsecDashboards;
      }
    ];
  };

  # Sandbox grafana loopback access. Allow responses to incoming connections
  # (Caddy reverse proxy) and outbound to Loki and Prometheus only.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 3100 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 9090 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner grafana -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 3100 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -p tcp --dport 9090 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner grafana -o lo -j REJECT || true
  '';
}
