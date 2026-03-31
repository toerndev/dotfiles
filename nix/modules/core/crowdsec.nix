{ lib, ... }:
{
  # Override DynamicUser so the stable crowdsec system user is used.
  # Required to add it to the caddy group for reading /var/log/caddy/*.log
  # (mode 0640, caddy group). Same pattern as alloy.nix.
  users.users.crowdsec.extraGroups = [ "caddy" ];

  systemd.services.crowdsec.serviceConfig.DynamicUser = lib.mkForce false;

  services.crowdsec = {
    enable = true;

    # Standalone mode: run both LAPI server and agent on this machine.
    # Required for the firewall bouncer to query decisions locally.
    settings.general.api.server.enable = true;

    # Path where machine registration credentials are written on first boot.
    settings.lapi.credentialsFile = "/etc/crowdsec/local_api_credentials.yaml";

    hub.collections = [
      "crowdsecurity/linux"  # sshd-logs parser + ssh-bf scenarios
      "crowdsecurity/caddy"  # caddy-logs parser + http scenarios
    ];

    localConfig.acquisitions = [
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
        labels.type = "syslog";
      }
      {
        source = "file";
        filenames = [ "/var/log/caddy/*.log" ];
        labels.type = "caddy";
      }
    ];
  };

  # Firewall bouncer: queries LAPI for decisions, blocks IPs via iptables INPUT.
  # registerBouncer.enable auto-registers against the local LAPI on first boot.
  services.crowdsec-firewall-bouncer = {
    enable = true;
    registerBouncer.enable = true;
  };

  # The nixpkgs module has Requires= but not After= for the register service,
  # so the bouncer races to load the credential file before it's written.
  # Adding After= ensures the register oneshot completes first.
  systemd.services.crowdsec-firewall-bouncer.after = [
    "crowdsec-firewall-bouncer-register.service"
  ];
}
