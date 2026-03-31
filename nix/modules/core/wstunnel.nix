{ pkgs, ... }:
{
  users.users.wstunnel = { isSystemUser = true; group = "wstunnel"; };
  users.groups.wstunnel = {};

  systemd.services.wstunnel = {
    description = "wstunnel WebSocket-to-WireGuard server";
    after    = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User  = "wstunnel";
      Group = "wstunnel";
      Type  = "simple";
      ExecStart = "${pkgs.wstunnel}/bin/wstunnel server --restrict-to 127.0.0.1:51820 ws://127.0.0.1:8181";
      Restart    = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges         = true;
      PrivateTmp              = true;
      ProtectSystem           = "strict";
      ProtectHome             = true;
      ProtectKernelTunables   = true;
      ProtectKernelModules    = true;
      ProtectControlGroups    = true;
      ProtectClock            = true;
      ProtectHostname         = true;
      ProtectKernelLogs       = true;
      LockPersonality         = true;
      MemoryDenyWriteExecute  = true;
      RestrictNamespaces      = true;
      RestrictRealtime        = true;
      RestrictSUIDSGID        = true;
      RemoveIPC               = true;
      RestrictAddressFamilies = [ "AF_INET" ];
      CapabilityBoundingSet   = "";
      AmbientCapabilities     = "";
      SystemCallFilter        = [ "@system-service" ];
      SystemCallArchitectures = "native";
    };
  };

  # Public HTTPS endpoint — Caddy terminates TLS, proxies WebSocket to wstunnel.
  # WireGuard's pre-shared key auth makes the tunnel unusable without the peer key.
  services.caddy.virtualHosts."wg.datasvard.com" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      reverse_proxy 127.0.0.1:8181

      log {
        output file /var/log/caddy/access-wg-tunnel.log {
          mode 0640
        }
        format json
      }
    '';
  };

  # Sandbox wstunnel loopback access: allow replies to Caddy (ESTABLISHED),
  # outbound UDP to WireGuard (port 51820), reject everything else.
  # The caddy→8181 ACCEPT must appear before the Caddy terminating REJECT in
  # hosts/htpc/default.nix; placing it here (services tier) ensures correct ordering.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy    -o lo -p tcp --dport 8181  -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner wstunnel -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner wstunnel -o lo -p udp --dport 51820 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner wstunnel -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy    -o lo -p tcp --dport 8181  -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner wstunnel -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner wstunnel -o lo -p udp --dport 51820 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner wstunnel -o lo -j REJECT || true
  '';
}
