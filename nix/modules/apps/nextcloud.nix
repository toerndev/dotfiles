{ config, lib, pkgs, ... }:
let
  # The NixOS nextcloud module stores extraApps in a separate nix store path and
  # configures Nextcloud to generate URLs with the /nix-apps/ prefix. The nginx
  # module wires a location block for /nix-apps/ automatically; since we use Caddy
  # we must replicate that: build a single directory with each app as a subdirectory
  # and serve it from a dedicated handle block.
  appsStore = pkgs.linkFarm "nextcloud-extra-apps"
    (lib.mapAttrsToList (name: pkg: { inherit name; path = pkg; })
      config.services.nextcloud.extraApps);
in
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "cloud.datasvard.com";

    # Tell Nextcloud it is accessed over HTTPS (sets overwriteprotocol).
    # Caddy terminates TLS; PHP-FPM receives plain HTTP on the unix socket.
    https = true;

    # PostgreSQL via local unix socket. The module creates the role + database
    # automatically; do NOT use SQLite (concurrent sync clients trigger "database
    # is locked" errors that are hard to migrate away from later).
    database.createLocally = true;
    config.dbtype = "pgsql";

    # Admin credentials read from sops-managed secret file.
    config.adminpassFile = config.sops.secrets.nextcloud_admin_password.path;
    config.adminuser = "admin";

    # Caddy reverse-proxies from 127.0.0.1 — trust X-Forwarded-For from there.
    settings.trusted_proxies = [ "127.0.0.1" ];

    maxUploadSize = "16G";
    # configureRedis defaults to true — the module creates services.redis.servers.nextcloud
    # and wires up the unix socket automatically.

    # High-performance push backend. Starts nextcloud-notify_push.service bound to
    # a unix socket (SOCKET_PATH=/run/nextcloud-notify_push/sock). Sync clients
    # receive immediate change notifications instead of polling every 30 s.
    # Caddy routes /push/* to the socket (see vhost below).
    # Verify after deploy: sudo -u nextcloud nextcloud-occ notify_push:self-test
    notify_push.enable = true;

    extraAppsEnable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit
        calendar
        contacts
        deck
        music
        news
        notes
        polls
        tasks;
    };
  };

  # The nextcloud module enables nginx by default; we use Caddy instead.
  services.nginx.enable = false;

  # notify_push validates tokens by calling NEXTCLOUD_URL (set by the NixOS module
  # to https://cloud.datasvard.com). From the server itself that request goes via
  # NAT hairpinning and arrives at Caddy from the router IP (192.168.1.1), which
  # is not a trusted proxy — Nextcloud rejects it. Override NEXTCLOUD_URL to the
  # loopback vhost below so the push server reaches PHP-FPM directly via 127.0.0.1,
  # which IS a trusted proxy.
  systemd.services.nextcloud-notify_push.environment.NEXTCLOUD_URL = lib.mkForce "http://127.0.0.1";

  # Allow Caddy to connect to the PHP-FPM unix socket.
  # The socket is at /run/phpfpm/nextcloud.sock; unix sockets are not subject
  # to the loopback iptables OUTPUT rules, so no firewall changes are needed.
  services.phpfpm.pools.nextcloud.settings = {
    "listen.owner" = "caddy";
    "listen.group" = "caddy";
  };
  users.users.caddy.extraGroups = [ "nextcloud" ];
  # extraGroups only takes effect on process start, not reload. Declaring it
  # here forces a caddy restart (not just reload) when first applied, and
  # ensures the group is in the service's credentials on every subsequent boot.
  systemd.services.caddy.serviceConfig.SupplementaryGroups = "nextcloud";

  # Loopback-only HTTP vhost so notify_push can reach Nextcloud PHP without going
  # through NAT hairpinning. No TLS, no public exposure — loopback only.
  # trusted_proxies for loopback is set globally in caddy.nix (servers block) because
  # Caddy does not support trusted_proxies as a site-level directive.
  services.caddy.virtualHosts."http://127.0.0.1" = {
    listenAddresses = [ "127.0.0.1" ];
    extraConfig = ''
      root * ${config.services.nextcloud.package}

      handle {
        php_fastcgi unix//run/phpfpm/nextcloud.sock {
          env front_controller_active true
        }
        file_server
      }
    '';
  };

  # Caddy vhost for Nextcloud. Served publicly on cloud.datasvard.com with
  # DNS-01 ACME via the CF_API_TOKEN already in Caddy's EnvironmentFile.
  # Cloudflare A record for "cloud" must exist before ddclient can update it.
  services.caddy.virtualHosts."cloud.datasvard.com" = {
    extraConfig = ''
      root * ${config.services.nextcloud.package}

      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }

      # WebDAV service discovery
      redir /.well-known/carddav /remote.php/dav 301
      redir /.well-known/caldav  /remote.php/dav 301
      redir /.well-known/webfinger /index.php/.well-known/webfinger 301
      redir /.well-known/nodeinfo  /index.php/.well-known/nodeinfo  301

      # Block access to sensitive paths
      @forbidden {
        path /.htaccess /data/* /config/* /lib/* /3rdparty/* /templates/* /build/*
      }
      respond @forbidden 404

      # notify_push WebSocket (/push/ws) and event endpoint (/push/event).
      # Must precede the catch-all handle block so these paths are not passed to PHP.
      # NixOS module binds notify_push to a unix socket (SOCKET_PATH env), not TCP.
      handle /push/* {
        reverse_proxy unix//run/nextcloud-notify_push/sock
      }

      # Extra apps (calendar, contacts, notes, etc.) live in a separate nix store
      # path - not under ${config.services.nextcloud.package}. Nextcloud generates
      # /nix-apps/<appname>/... URLs for them; serve those files directly without
      # going through PHP.
      handle /nix-apps/* {
        uri strip_prefix /nix-apps
        root * ${appsStore}
        file_server
      }

      handle {
        php_fastcgi unix//run/phpfpm/nextcloud.sock {
          env front_controller_active true
        }
        file_server
      }

      log {
        output file /var/log/caddy/access-nextcloud.log {
          mode 0640
        }
        format json
      }
    '';
  };
}
