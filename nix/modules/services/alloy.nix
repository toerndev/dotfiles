{ pkgs, lib, ... }:
{
  users.users.alloy = {
    isSystemUser = true;
    group = "alloy";
    extraGroups = [ "caddy" ];
  };
  users.groups.alloy = { };

  services.alloy = {
    enable = true;
    configPath = pkgs.writeText "alloy-config.alloy" ''
      // Caddy access logs → Loki
      local.file_match "caddy_logs" {
        path_targets = [{"__path__" = "/var/log/caddy/*.log"}]
      }

      loki.source.file "caddy" {
        targets    = local.file_match.caddy_logs.targets
        forward_to = [loki.write.local.receiver]
      }

      loki.write "local" {
        endpoint {
          url = "http://127.0.0.1:3100/loki/api/v1/push"
        }
      }
    '';
    extraFlags = [ "--disable-reporting" ];
  };

  # Override DynamicUser so --uid-owner alloy works in iptables.
  systemd.services.alloy.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "alloy";
    Group = "alloy";
  };

  # Alloy only needs to push to local Loki.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner alloy -o lo -p tcp --dport 3100 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner alloy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner alloy -o lo -p tcp --dport 3100 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner alloy -o lo -j REJECT || true
  '';
}
