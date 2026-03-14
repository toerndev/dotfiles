{ ... }:
{
  imports = [
    ./media-storage.nix
    ./jellyfin.nix
    ./htpc.nix
    ./homepage.nix
    ./grafana.nix
    ./loki.nix
  ];
}
