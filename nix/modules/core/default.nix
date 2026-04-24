{ ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./packages.nix
    ./secrets.nix
    ./caddy.nix
    ./ddclient.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./wireguard.nix
    ./wstunnel.nix
    ./alloy.nix
    ./crowdsec.nix
    ./endlessh.nix
    ./grafana.nix
    ./loki.nix
    ./prometheus.nix
    ./backup.nix
  ];
}
