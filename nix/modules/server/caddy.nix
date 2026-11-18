{ config, pkgs, lib, ... }:
{
  services.caddy = {
    enable = true;

    # caddy-dns/cloudflare plugin for DNS-01 ACME challenge.
    # To get the correct vendorHash: set hash = lib.fakeHash, run
    #   nix build .#nixosConfigurations.server.config.services.caddy.package
    # then replace lib.fakeHash with the hash nix reports.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.0.0-20251204174556-6dc1fbb7e925" ];
      hash = "sha256-LLeIR/l1TnMPVEu6kGryg2oPT4GjvWzM8iI6adgq8IE=";
    };

    # Unix socket instead of "admin off". Caddy's reload mechanism
    # sends the new config via the admin API, so it must be reachable.
    globalConfig = ''
      admin unix//run/caddy/admin.sock
    '';

    virtualHosts."datasvard.com" = {
      extraConfig = ''
        root * /var/www/public
        file_server browse

        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }

        log {
          output file /var/log/caddy/access-public.log {
            mode 0640
          }
          format json
        }
      '';
    };

    virtualHosts."http://10.100.0.1" = {
      listenAddresses = [ "10.100.0.1" ];
      extraConfig = ''
        handle {
          reverse_proxy localhost:8082
        }

        log {
          output file /var/log/caddy/access-wg.log {
            mode 0640
          }
          format json
        }
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 80 ];

  # Loopback sandbox: caddy may only reach its backends. Each module adds its
  # own ACCEPT; the terminating REJECT is in hosts/server/default.nix, which
  # merges last.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT
    # DNS goes through systemd-resolved's stub; the ACME DNS-01 zone lookup needs it.
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -d 127.0.0.53 -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -d 127.0.0.53 -p tcp --dport 53 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8082 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -d 127.0.0.53 -p udp --dport 53 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -d 127.0.0.53 -p tcp --dport 53 -j ACCEPT || true
  '';

  systemd.services.caddy.serviceConfig = {
    EnvironmentFile = config.sops.templates."caddy-cloudflare-env".path;
    RuntimeDirectory = "caddy";
    ReadWritePaths = [ "/var/log/caddy" "/var/lib/caddy" ];
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
    "d /var/log/caddy 0750 caddy caddy -"
  ];
}
