{ ... }:
{
  services.nginx = {
    enable = true;

    virtualHosts."public" = {
      listen = [{ addr = "0.0.0.0"; port = 80; }];
      root = "/var/www/public";
      extraConfig = "autoindex on;";
    };

    virtualHosts."wg" = {
      listen = [{ addr = "10.100.0.1"; port = 80; }];
      root = "/var/www/internal";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];

  # Sandbox nginx loopback access — when adding reverse proxy backends,
  # add ACCEPT rules before the REJECT line:
  #   iptables -A OUTPUT -m owner --uid-owner nginx -o lo -p tcp --dport 8082 -j ACCEPT
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner nginx -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner nginx -o lo -j REJECT || true
  '';

  systemd.services.nginx.serviceConfig = {
    ProtectSystem = "strict";
    ProtectHome = true;
    NoNewPrivileges = true;
    CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_SETUID" "CAP_SETGID" ];
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
