# Every host: boot, locale, networking (networkd + homelab.lanInterface), nix,
# packages, SSH hardening, the losipai user. Host-specific values (hostname,
# NIC, sshd listen address, system.stateVersion) are set in hosts/<name>.
{ ... }:
{
  imports = [
    ./boot.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./ssh.nix
    ./users.nix
  ];
}
