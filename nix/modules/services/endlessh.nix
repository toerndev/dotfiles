{ ... }:
{
  services.endlessh-go = {
    enable = true;
    # Bind to LAN/public interface. WireGuard goes to real sshd.
    listenAddress = "192.168.1.70";
    port = 22;
    prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 2112;
    };
    openFirewall = true;
  };
}
