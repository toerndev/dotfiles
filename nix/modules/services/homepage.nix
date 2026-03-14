{ ... }:
{
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
        "Observability" = [
          {
            "Grafana" = {
              href = "http://10.100.0.1:3000";
              description = "Dashboards (Phase 2)";
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
          disk = "/";
        };
      }
    ];
  };

  # Bind to localhost only — Caddy reverse-proxies on the WG vhost.
  systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1";
}
