# The always-on box (ASUS NUC 16 Pro): WireGuard, wstunnel, Caddy, ddclient,
# zigbee, Jellyfin, Homepage, Directus + site-builder.
{ inputs, pkgs, ... }:
{
  # Import order matters: list options (firewall extraCommands) merge in this
  # order, and the REJECT below has to come after every module's ACCEPT.
  imports = [
    ./hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops

    ../../modules/common

    ../../modules/server/secrets.nix
    ../../modules/server/caddy.nix
    ../../modules/server/ddclient.nix
    ../../modules/server/wireguard.nix
    ../../modules/server/wstunnel.nix
    # ../../modules/server/backup.nix
    #   Not yet: it mounts the /backup disk, which stays in the htpc. Phase 5 of
    #   context/nix-migration.md points the repo at the htpc over SSH and brings
    #   it back. Until then nothing here is backed up, zigbee's data included.

    ../../modules/apps/media-storage.nix
    ../../modules/apps/jellyfin.nix
    ../../modules/apps/homepage.nix
    ../../modules/apps/directus
    ../../modules/apps/site-builder
    ../../modules/apps/zigbee
  ];

  networking.hostName = "server";

  # TODO: the NUC's NIC name, from `ip -br link` on the NixOS USB (Phase 2).
  homelab.lanInterface = "enp0s0";

  # The NUC 16 Pro's platform is newer than the release's default kernel
  # (6.12 LTS on 25.11); idle power depends on platform support.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # sshd on WireGuard only: there is nothing listening on :22 on the LAN or WAN.
  services.openssh.listenAddresses = [ { addr = "10.100.0.1"; } ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];

  # The NixOS release this host was first installed with. Set it at install
  # and never change it afterwards (it is not the running version).
  system.stateVersion = "25.11";

  # Terminating REJECT for caddy loopback sandbox.
  # Must live here (host file) so it is always appended AFTER all service-module
  # ACCEPT rules. types.lines merges in evaluation order (modules → host),
  # so a REJECT placed in any module would precede ACCEPT rules from later modules.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -j REJECT || true
  '';
}
