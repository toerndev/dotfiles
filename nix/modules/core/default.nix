{ ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./secrets.nix
    ./caddy.nix
    ./ddclient.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./wireguard.nix
  ];
}
