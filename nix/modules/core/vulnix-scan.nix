{ pkgs, pkgs-unstable, ... }:
let
  scanScript = pkgs.writeShellScript "vulnix-scan" ''
    set -uo pipefail
    ${pkgs-unstable.vulnix}/bin/vulnix --system --json > /var/www/public/vulnix.json.tmp || true
    mv /var/www/public/vulnix.json.tmp /var/www/public/vulnix.json
  '';
in
{
  systemd.services.vulnix-scan = {
    description = "Scan NixOS for known vulnerabilities";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = scanScript;
    };
  };

  systemd.timers.vulnix-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/12:00:00";
      OnActiveSec = "0";
      Persistent = true;
    };
  };
}
