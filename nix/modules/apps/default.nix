{ ... }:
{
  imports = [
    ./media-storage.nix
    ./jellyfin.nix
    ./htpc.nix
    ./homepage.nix
    ./directus
    ./site-builder
    ./zigbee
  ];
}
