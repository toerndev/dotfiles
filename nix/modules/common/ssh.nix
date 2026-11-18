{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    # Hardening only. Where sshd listens, and which firewall ports open for
    # it, is set per host (server: WireGuard only; htpc: LAN).
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
    };
    openFirewall = false;
  };
}
