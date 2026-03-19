{ config, pkgs, ... }:
{
  services.openssh = {
    enable = true;
    # Restrict to WireGuard interface only, port 22 on LAN/public goes to endlessh-go.
    listenAddresses = [ { addr = "10.100.0.1"; } ];
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
