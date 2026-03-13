{ ... }:
{
  services.caddy = {
    enable = true;
    globalConfig = "admin off";

    virtualHosts."http://" = {
      extraConfig = ''
        root * /var/www/public
        file_server browse
      '';
    };

    virtualHosts."http://10.100.0.1" = {
      listenAddresses = [ "10.100.0.1" ];
      extraConfig = "reverse_proxy localhost:8082";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  # Sandbox caddy loopback access — only allow backends it proxies to.
  # Phase 2: add ACCEPT for :3000 (Grafana) and :3100 (Loki).
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -j REJECT || true
  '';

  systemd.services.caddy.serviceConfig = {
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    SystemCallFilter = [ "@system-service" ];
    SystemCallArchitectures = "native";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
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
