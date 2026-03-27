{ ... }:
{
  imports = [
    ./media-storage.nix
    ./jellyfin.nix
    ./htpc.nix
    ./homepage.nix
    ./grafana.nix
    ./loki.nix
    ./prometheus.nix
    ./alloy.nix
    ./endlessh.nix
    ./crowdsec.nix
    ./nextcloud.nix
    ./immich.nix
  ];
}
