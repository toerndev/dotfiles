# Zigbee lights: mosquitto + zigbee2mqtt + the zigbee-lamps rules service.
# Everything about it -- hardware, setting up from scratch, adding lights and
# sensors, the rules -- is in README.md next to this file.
{ config, pkgs, ... }:
let
  lampsPython = pkgs.python3.withPackages (ps: [ ps.paho-mqtt ]);
  # A string, not ./path: the service runs the code and reads rules.toml from
  # this checkout, so editing either needs no rebuild (README: "What needs what").
  lampsDir = "/home/losipai/github/dotfiles/nix/modules/apps/zigbee";
  lampctl = pkgs.writeShellScriptBin "lampctl" ''
    exec ${lampsPython}/bin/python3 ${lampsDir}/ctl.py "$@"
  '';
in
{
  services.mosquitto = {
    enable = true;
    listeners = [{
      address = "127.0.0.1";
      port = 1883;
      settings.allow_anonymous = true;
      # The module always emits an acl_file, and an empty one is default-deny:
      # clients connect, publishes succeed, and nothing is ever delivered.
      acl = [ "pattern readwrite #" ];
    }];
  };
  # The ACL is an /etc file outside the unit; without this a switch that only
  # changes it leaves the running broker on the old rules. HUP rereads them.
  systemd.services.mosquitto.reloadTriggers =
    [ config.environment.etc."mosquitto/acl-0.conf".source ];

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      permit_join = false;
      # SLZB-06U in network mode: the radio is on TCP only. Its USB port is the
      # ESP32's debug console (and its power), never the radio.
      serial = {
        port = "tcp://SLZB-06U.lan:6638";
        adapter = "zstack";
      };
      mqtt.server = "mqtt://localhost:1883";
      frontend = {
        port = 8083;
        host = "127.0.0.1";
      };
      availability.enabled = true;
      # Network parameters (channel, PAN ids, key) are z2m's defaults and live
      # in the coordinator; see README "The network" before setting any here.
      # Device names and options are not set here either: the module's default
      # `devices = "devices.yaml"` is a file z2m owns, so renames persist.
    };
  };

  # The coordinator is reached via the router (DNS + TCP), so a router reboot
  # looks like the adapter vanishing. The defaults (100ms restarts, 5 starts per
  # 10s) give up for good before the router is back; keep retrying instead.
  systemd.services.zigbee2mqtt = {
    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = 10;
    # Never start with an empty data dir: z2m may form a fresh network, and
    # every device has to be paired again. Restore the files first (README:
    # "Setting up from scratch and recovery"). To form a new network on
    # purpose: sudo touch /var/lib/zigbee2mqtt/form-new-network
    unitConfig.ConditionPathExists = [
      "|${config.services.zigbee2mqtt.dataDir}/coordinator_backup.json"
      "|${config.services.zigbee2mqtt.dataDir}/form-new-network"
    ];
  };

  # Backups of the network files are declared in modules/server/backup.nix,
  # so this module works without Borg.

  systemd.services.zigbee-lamps = {
    description = "Rules for Zigbee lamps (zigbee/rules.toml)";
    after = [ "mosquitto.service" "zigbee2mqtt.service" ];
    wants = [ "mosquitto.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${lampsPython}/bin/python3 -u ${lampsDir}/main.py";
      # The code lives in this home directory, which is mode 700.
      User = "losipai";
      Group = "users";
      Restart = "always";
      RestartSec = 5;
    };
  };

  environment.systemPackages = [ pkgs.mosquitto lampctl ];

  # Frontend over WireGuard: http://10.100.0.1:8083
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
