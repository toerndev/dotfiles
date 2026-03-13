{ ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./caddy.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./wireguard.nix
  ];
}
