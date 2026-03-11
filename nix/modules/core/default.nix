{ ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./nginx.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./wireguard.nix
  ];
}
