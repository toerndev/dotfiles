# First install of the server: just enough to log in over the LAN and finish
# from there. No WireGuard, sops, Caddy or zigbee; DHCP on every NIC, so the
# NIC's name isn't needed yet. Then, on the box: check homelab.lanInterface in
# hosts/server, `nixos-rebuild test --sudo --flake ~/github/dotfiles/nix#server`
# (SSH moves to WireGuard), then `switch`.
{ pkgs, ... }:
{
  imports = [
    ../server/hardware-configuration.nix

    # modules/common without networking.nix (that one needs the NIC name)
    ../../modules/common/boot.nix
    ../../modules/common/locale.nix
    ../../modules/common/nix.nix
    ../../modules/common/packages.nix
    ../../modules/common/ssh.nix
    ../../modules/common/users.nix
  ];

  networking.hostName = "server";
  networking.useDHCP = true;

  # Same kernel as hosts/server: the NIC has to work on first boot.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # sshd on the LAN (key-only, common/ssh.nix): there's no WireGuard yet.
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Same as hosts/server: the release the NUC is installed with.
  system.stateVersion = "25.11";
}
