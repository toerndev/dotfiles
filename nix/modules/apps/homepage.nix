{ lib, ... }:
{
  # DynamicUser = true (module default) means no /etc/passwd entry, so
  # --uid-owner in iptables cannot resolve the name. Same fix as ddclient.
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

  # Loopback sandbox: replies to Caddy only, no outbound loopback connections.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner homepage-dashboard -o lo -j REJECT || true
  '';
}
