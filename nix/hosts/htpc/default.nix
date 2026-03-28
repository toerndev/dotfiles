{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/services
  ];

  networking.hostName = "htpc";

  # Terminating REJECT for caddy loopback sandbox.
  # Must live here (host file) so it is always appended AFTER all service-module
  # ACCEPT rules. types.lines merges in evaluation order (core → services → host),
  # so a REJECT placed in any module would precede ACCEPT rules from later modules.
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -j REJECT || true
  '';
}
