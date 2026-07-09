{ ... }:
{
  services.mosquitto = {
    enable = true;
    listeners = [{
      address = "127.0.0.1";
      port = 1883;
      settings.allow_anonymous = true;
    }];
  };

  users.users.zigbee2mqtt.extraGroups = [ "dialout" ];

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      permit_join = false;
      serial = {
        port = "/dev/ttyACM0";
        adapter = "ezsp";
      };
      mqtt.server = "mqtt://localhost:1883";
      frontend = {
        port = 8083;
        host = "127.0.0.1";
      };
    };
  };

  services.caddy.virtualHosts."http://10.100.0.1:8083" = {
    listenAddresses = [ "10.100.0.1" ];
    extraConfig = ''
      reverse_proxy localhost:8083

      log {
        output file /var/log/caddy/access-zigbee2mqtt.log {
          mode 0640
        }
        format json
      }
    '';
  };

  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 8083 ];

  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8083 -j ACCEPT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8083 -j ACCEPT || true
  '';
}
