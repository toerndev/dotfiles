{ lib, pkgs, ... }:
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

  # Register a CrowdSec machine (watcher) for Homepage on every boot.
  # Credentials land in /run/ (ephemeral) — no sops needed.
  # Uses the same oneshot pattern as crowdsec-firewall-bouncer-register.
  systemd.services.crowdsec-homepage-register = {
    description = "Register Homepage as CrowdSec watcher";
    after = [ "crowdsec.service" ];
    wants = [ "crowdsec.service" ];
    before = [ "homepage-dashboard.service" ];
    wantedBy = [ "homepage-dashboard.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # world-executable so homepage-dashboard can traverse into the dir;
      # the credentials file itself is locked to root:homepage-dashboard 640.
      RuntimeDirectory = "crowdsec-homepage";
      RuntimeDirectoryMode = "0755";
    };
    script = ''
      creds=/run/crowdsec-homepage/credentials
      # The NixOS module passes the config via -c /nix/store/…/crowdsec.yaml (no
      # stable /etc/crowdsec/config.yaml). Read the path from the running process.
      pid=$(systemctl show crowdsec -p MainPID --value)
      cfg=$(tr '\0' '\n' < /proc/"$pid"/cmdline | ${pkgs.gawk}/bin/awk '/^-c$/{getline; print; exit}')
      pw=$(head -c 48 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
      ${pkgs.crowdsec}/bin/cscli -c "$cfg" machines delete homepage-widget 2>/dev/null || true
      ${pkgs.crowdsec}/bin/cscli -c "$cfg" machines add homepage-widget --password "$pw" -f -
      printf 'HOMEPAGE_VAR_CROWDSEC_USERNAME=homepage-widget\nHOMEPAGE_VAR_CROWDSEC_PASSWORD=%s\n' "$pw" > "$creds"
      chown root:homepage-dashboard "$creds"
      chmod 640 "$creds"
    '';
  };
}
