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
              description = "IDS / firewall bouncer";
              widget = {
                type = "customapi";
                # label_replace gives each scalar a unique "_m" label so `or` keeps both
                # results distinct. result[0]=total active decisions, result[1]=locally
                # detected (origin="crowdsec") vs CAPI/lists. Avoids the LAPI limit=100 cap.
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28sum%28cs_active_decisions%29%20or%20vector%280%29%2C%22_m%22%2C%221%22%2C%22%22%2C%22%22%29%20or%20label_replace%28sum%28cs_active_decisions%7Borigin%3D%22crowdsec%22%7D%29%20or%20vector%280%29%2C%22_m%22%2C%222%22%2C%22%22%2C%22%22%29";
                mappings = [
                  {
                    field = "data.result.0.value.1";
                    label = "Blocked";
                    format = "number";
                  }
                  {
                    field = "data.result.1.value.1";
                    label = "Local";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "Endlessh" = {
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
        "Network" = [
          {
            "OpenWrt" = {
              href = "http://192.168.1.1";
              description = "WAN traffic";
              widget = {
                type = "customapi";
                # Insertion order: [0]=WAN RX, [1]=WAN TX, [2]=clients, [3]=conntrack.
                # Adjust device="eth1" to match your WAN interface if needed.
                url = "http://127.0.0.1:9090/api/v1/query?query=label_replace%28rate%28node_network_receive_bytes_total%7Bjob%3D%22openwrt%22%2Cdevice%3D%22eth1%22%7D%5B5m%5D%29%2C%22_m%22%2C%221%22%2C%22%22%2C%22%22%29%20or%20label_replace%28rate%28node_network_transmit_bytes_total%7Bjob%3D%22openwrt%22%2Cdevice%3D%22eth1%22%7D%5B5m%5D%29%2C%22_m%22%2C%222%22%2C%22%22%2C%22%22%29%20or%20label_replace%28sum%28wifi_stations%7Bjob%3D%22openwrt%22%7D%29%2C%22_m%22%2C%223%22%2C%22%22%2C%22%22%29%20or%20label_replace%28node_nf_conntrack_entries%7Bjob%3D%22openwrt%22%7D%2C%22_m%22%2C%224%22%2C%22%22%2C%22%22%29";
                mappings = [
                  {
                    field = "data.result.0.value.1";
                    label = "WAN ↓";
                    format = "bytes";
                    suffix = "/s";
                  }
                  {
                    field = "data.result.1.value.1";
                    label = "WAN ↑";
                    format = "bytes";
                    suffix = "/s";
                  }
                  {
                    field = "data.result.2.value.1";
                    label = "Clients";
                    format = "number";
                  }
                  {
                    field = "data.result.3.value.1";
                    label = "Conns";
                    format = "number";
                  }
                ];
              };
            };
          }
          {
            "OpenWrt — CPU Load" = {
              href = "http://192.168.1.1";
              description = "Cortex-A53 quad-core @ 2 GHz";
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:9090/api/v1/query?query=node_load1%7Bjob%3D%22openwrt%22%7D";
                mappings = [
                  {
                    field = "data.result.0.value.1";
                    label = "Load";
                    format = "float";
                    decimals = 2;
                  }
                ];
              };
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
  systemd.services.homepage-dashboard = {
    environment = {
      HOSTNAME = "127.0.0.1";
      HOMEPAGE_ALLOWED_HOSTS = lib.mkForce "localhost:8082,127.0.0.1:8082,10.100.0.1";
    };
  };

  # Loopback sandbox: allow Prometheus (9090) only.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 9090 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -p tcp --dport 9090 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT || true
  '';
}
