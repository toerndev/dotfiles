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
    ./vulnix-scan.nix
    ./wireguard.nix
  ];
}
