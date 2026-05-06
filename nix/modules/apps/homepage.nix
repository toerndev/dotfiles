{ lib, ... }:
{
  # DynamicUser = true (module default) means no /etc/passwd entry, so
  # --uid-owner in iptables cannot resolve the name. Same fix as alloy/crowdsec/ddclient.
  users.users.homepage-dashboard = {
    isSystemUser = true;
    group = "homepage-dashboard";
  };
  users.groups.homepage-dashboard = { };
  systemd.services.homepage-dashboard.serviceConfig.DynamicUser = lib.mkForce false;

  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    openFirewall = false;

    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              href = "http://10.100.0.1:8096";
              description = "Media server";
            };
          }
        ];
      }
      {
        "Security" = [
          {
            "CrowdSec" = {
              href = "http://10.100.0.1/grafana";
              description = "IDS / firewall bouncer";
              widget = {
                type = "crowdsec";
                url = "http://127.0.0.1:8080";
                username = "{{HOMEPAGE_VAR_CROWDSEC_USERNAME}}";
                password = "{{HOMEPAGE_VAR_CROWDSEC_PASSWORD}}";
              };
            };
          }
          {
            "Endlessh" = {
              href = "http://10.100.0.1/grafana";
              description = "SSH tarpit";
              widget = {
                type = "customapi";
                # label_replace adds a synthetic "w" label to each metric so `or` does not
                # deduplicate them (Prometheus `or` ignores __name__ when comparing fingerprints;
                # all four share the same job/instance labels without this). Left-to-right `or`
                # insertion order gives result[0]=today, [1]=7d, [2]=30d, [3]=all-time.
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28endlessh_bots_01d%2C%22w%22%2C%221%22%2C%22%22%2C%22%22%29%20or%20label_replace%28endlessh_bots_07d%2C%22w%22%2C%227%22%2C%22%22%2C%22%22%29%20or%20label_replace%28endlessh_bots_30d%2C%22w%22%2C%2230%22%2C%22%22%2C%22%22%29%20or%20label_replace%28endlessh_client_closed_count_total%2C%22w%22%2C%22all%22%2C%22%22%2C%22%22%29";
                mappings = [
                  {
                    field = "data.result.0.value.1";
                    label = "Today";
                    format = "number";
                  }
                  {
                    field = "data.result.1.value.1";
                    label = "7 days";
                    format = "number";
                  }
                  {
                    field = "data.result.2.value.1";
                    label = "30 days";
                    format = "number";
                  }
                  {
                    field = "data.result.3.value.1";
                    label = "All time";
                    format = "number";
                  }
                ];
              };
            };
          }

        ];
      }
      {
        "Observability" = [
          {
            "Grafana" = {
              href = "http://10.100.0.1/grafana";
              description = "Dashboards & logs";
            };
          }
        ];
      }
    ];

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = [ "/" "/media" ];
        };
      }
    ];
  };

  # Bind to localhost only, Caddy reverse-proxies on the WG vhost.
  # HOMEPAGE_ALLOWED_HOSTS allows the Host header Caddy forwards (10.100.0.1).
  # EnvironmentFile supplies CROWDSEC_USERNAME/PASSWORD from the boot oneshot.
  systemd.services.homepage-dashboard = {
    environment = {
      HOSTNAME = "127.0.0.1";
      HOMEPAGE_ALLOWED_HOSTS = lib.mkForce "localhost:8082,127.0.0.1:8082,10.100.0.1";
    };
    serviceConfig.EnvironmentFile = lib.mkForce "/run/crowdsec-homepage/credentials";
  };

  # Loopback sandbox: allow Prometheus (9090) and CrowdSec LAPI (8080) only.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 9090 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 8080 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 9090 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 8080 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT || true
  '';
}
