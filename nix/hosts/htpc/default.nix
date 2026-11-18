# The living-room box (Ryzen 8700G): Kodi, Steam, RetroArch. After Phase 5 of
# context/nix-migration.md also the Borg target for the server.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common
    ../../modules/htpc
  ];

  networking.hostName = "htpc";

  homelab.lanInterface = "enp8s0";

  # Keep the Wi-Fi radio (MediaTek MT7921) fully off: no driver, no wlp7s0.
  boot.blacklistedKernelModules = [ "mt7921e" ];

  # No WireGuard here: sshd on the LAN. Reach it from outside through the
  # server (`ssh -J losipai@10.100.0.1 losipai@<htpc>`). Phase 5 narrows this
  # to the server's IP.
  networking.firewall.interfaces.enp8s0.allowedTCPPorts = [ 22 ];

  # The NixOS release this host was first installed with. Still the current
  # install's; set it to the installer's release when the htpc is reinstalled
  # (Phase 4), together with the new hardware-configuration.nix.
  system.stateVersion = "24.11";
}
