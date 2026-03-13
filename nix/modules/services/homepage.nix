{ ... }:
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;

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
}
