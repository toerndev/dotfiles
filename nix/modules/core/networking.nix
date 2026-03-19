{ config, pkgs, ... }:
{
  networking.networkmanager.enable = true;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.templates."wifi-env".path ];
    profiles."wifi" = {
      connection = { id = "wifi"; type = "wifi"; autoconnect-priority = "10"; };
      wifi = { mode = "infrastructure"; ssid = "wpa_supplicant"; };
      wifi-security = { auth-alg = "open"; key-mgmt = "wpa-psk"; psk = "$WIFI_PSK"; };
      ipv4.method = "auto";
      ipv6 = { method = "auto"; addr-gen-mode = "stable-privacy"; };
    };
    profiles."wifi-2.4" = {
      connection = { id = "wifi-2.4"; type = "wifi"; autoconnect-priority = "5"; };
      wifi = { mode = "infrastructure"; ssid = "wpa_supplicant_2.4"; };
      wifi-security = { auth-alg = "open"; key-mgmt = "wpa-psk"; psk = "$WIFI_PSK"; };
      ipv4.method = "auto";
      ipv6 = { method = "auto"; addr-gen-mode = "stable-privacy"; };
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 8096 ];  # SSH + Jellyfin
  };
}
