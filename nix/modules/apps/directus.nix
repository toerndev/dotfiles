{ config, pkgs, ... }:
{
  users.users.directus = {
    isSystemUser = true;
    group = "directus";
    description = "Directus CMS service user";
  };
  users.groups.directus = {};

  # /srv/directus: code + node_modules, setgid so new files inherit directus group.
  #   losipai owns (full write for development); directus group read-only (runtime).
  # /var/lib/directus/uploads: runtime file uploads; parent created by StateDirectory.
  systemd.tmpfiles.rules = [
    "d /srv/directus 02750 losipai directus -"
    "d /var/lib/directus/uploads 0750 directus directus -"
  ];

  systemd.services.directus = {
    description = "Directus CMS";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      HOST = "127.0.0.1";
      PORT = "8055";
      PUBLIC_URL = "https://cms.datasvard.com";
      DB_CLIENT = "sqlite3";
      DB_FILENAME = "/var/lib/directus/database.sqlite";
      STORAGE_LOCATIONS = "local";
      STORAGE_LOCAL_ROOT = "/var/lib/directus/uploads";
      LOG_STYLE = "raw";
      LOG_LEVEL = "info";
      ADMIN_EMAIL = "admin@datasvard.com";
      # pm2 is used internally by `directus start` for worker clustering.
      # Without a writable home, pm2 crashes trying to create ~/.pm2/.
      PM2_HOME = "/var/lib/directus/.pm2";
    };

    serviceConfig = {
      User = "directus";
      Group = "directus";
      WorkingDirectory = "/srv/directus";

      # Run migrations and create admin account on first boot (idempotent).
      ExecStartPre = "${pkgs.nodejs}/bin/node /srv/directus/node_modules/.bin/directus bootstrap";
      ExecStart = "${pkgs.nodejs}/bin/node /srv/directus/node_modules/.bin/directus start";

      # SECRET and ADMIN_PASSWORD injected from sops template.
      EnvironmentFile = config.sops.templates."directus-env".path;

      # Creates /var/lib/directus and makes it writable for this service.
      StateDirectory = "directus";

      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening — no MemoryDenyWriteExecute: Node.js V8 JIT requires W+X pages.
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      ReadWritePaths = [ "/var/lib/directus" ];
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
      PrivateTmp = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };
  };

  # Public HTTPS vhost; DNS-01 via the existing Cloudflare token already in Caddy.
  # Pre-requisite: create the cms A record in Cloudflare manually before deploying
  # (ddclient only updates existing records, it cannot create them).
  services.caddy.virtualHosts."cms.datasvard.com" = {
    extraConfig = ''
      reverse_proxy localhost:8055

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      log {
        output file /var/log/caddy/access-directus.log {
          mode 0640
        }
        format json
      }
    '';
  };

  # python3Packages.setuptools provides distutils for node-gyp native build fallback.
  # On NixOS 25.11 with nix-ld enabled, prebuild-install downloads pre-built binaries
  # for Node.js 22 LTS (argon2, better-sqlite3, isolated-vm, sharp) which run via nix-ld.
  # Source compilation is only a fallback; gcc and gnumake already in core/locale.nix.
  environment.systemPackages = [ pkgs.python3Packages.setuptools ];

  # Loopback sandbox: caddy → directus (8055), directus replies only.
  # Directus has no legitimate outbound connections at runtime (SQLite + local storage).
  # Terminating caddy REJECT lives in hosts/htpc/default.nix (always last).
  networking.firewall.extraCommands = ''
    iptables -A OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8055 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner directus -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner directus -o lo -j REJECT
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D OUTPUT -m owner --uid-owner caddy -o lo -p tcp --dport 8055 -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner directus -o lo -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
    iptables -D OUTPUT -m owner --uid-owner directus -o lo -j REJECT || true
  '';
}
