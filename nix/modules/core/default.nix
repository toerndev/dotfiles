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
    ./backup.nix
  ];
}
