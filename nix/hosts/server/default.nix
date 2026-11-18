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
    # ../../modules/server/backup.nix: not imported, it still expects a local
    #   /backup disk. Nothing on this host is backed up, zigbee's data included.

    ../../modules/apps/media-storage.nix
    ../../modules/apps/jellyfin.nix
    ../../modules/apps/homepage.nix
    ../../modules/apps/directus
    ../../modules/apps/site-builder
    ../../modules/apps/zigbee
  ];

  networking.hostName = "server";

  # The NUC port labelled "1" (cabled); enp86s0 is the other port.
  homelab.lanInterface = "enp87s0";

  # The NUC 16 Pro's platform is newer than the release's default kernel
  # (6.12 LTS on 25.11); idle power depends on platform support.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # sshd on WireGuard only: there is nothing listening on :22 on the LAN or WAN.
  services.openssh.listenAddresses = [ { addr = "10.100.0.1"; } ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 22 ];
  # sshd and Caddy bind 10.100.0.1, which only exists once wg0 is up. Without
  # this they race wireguard-wg0 at boot ("Cannot assign requested address")
  # and can hit their start limit: no SSH on a headless box.
  boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

  # The release this host was installed with; never change it.
  system.stateVersion = "25.11";

  # Caddy's loopback sandbox ends here, after every module's ACCEPT (see the
  # import-order note at the top).
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -j REJECT || true
  '';
}
