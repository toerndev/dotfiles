{ ... }:
{
  services.caddy = {
    enable = true;
    # Unix socket instead of "admin off" — Caddy's reload mechanism
    # sends the new config via the admin API, so it must be reachable.
    globalConfig = "admin unix//run/caddy/admin.sock";

    virtualHosts."http://" = {
      extraConfig = ''
        root * /var/www/public
        file_server browse
      '';
    };

    virtualHosts."http://10.100.0.1" = {
      listenAddresses = [ "10.100.0.1" ];
      extraConfig = ''
        handle /grafana* {
          reverse_proxy localhost:3000
        }

        handle {
          reverse_proxy localhost:8082
        }
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  # Sandbox caddy loopback access — only allow backends it proxies to.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 3000 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 3000 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -j REJECT || true
  '';

  systemd.services.caddy.serviceConfig = {
    RuntimeDirectory = "caddy";
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    SystemCallFilter = [ "@system-service" ];
    SystemCallArchitectures = "native";
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RemoveIPC = true;
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    PrivateTmp = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/www/public 0755 root root -"
    "d /var/www/internal 0755 root root -"
  ];
}
