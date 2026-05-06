{ pkgs, ... }:
{
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;

    ruleFiles = [
      (pkgs.writeText "endlessh-rules.yaml" ''
        groups:
          - name: endlessh
            rules:
              - record: endlessh_bots_01d
                expr: floor(increase(endlessh_client_closed_count_total[1d]))
              - record: endlessh_bots_07d
                expr: floor(increase(endlessh_client_closed_count_total[7d]))
              - record: endlessh_bots_30d
                expr: floor(increase(endlessh_client_closed_count_total[30d]))
      '')
    ];

    exporters.node = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
    };

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }
      {
        job_name = "endlessh-go";
        static_configs = [{ targets = [ "127.0.0.1:2112" ]; }];
      }
      {
        job_name = "crowdsec";
        static_configs = [{ targets = [ "127.0.0.1:6060" ]; }];
      }
    ];
  };

  # Prometheus: respond to Grafana queries (ESTABLISHED), scrape node_exporter, reject rest.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner prometheus -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 9100 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 2112 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 6060 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner prometheus -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner prometheus -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 9100 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 2112 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner prometheus -o lo -p tcp --dport 6060 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner prometheus -o lo -j REJECT || true
  '';
}
