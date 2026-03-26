{ config, pkgs, ... }:
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
  };

  # The nextcloud module enables nginx by default; we use Caddy instead.
  services.nginx.enable = false;

  # Allow Caddy to connect to the PHP-FPM unix socket.
  # The socket is at /run/phpfpm/nextcloud.sock; unix sockets are not subject
  # to the loopback iptables OUTPUT rules, so no firewall changes are needed.
  services.phpfpm.pools.nextcloud.settings = {
    "listen.owner" = "caddy";
    "listen.group" = "caddy";
  };
  users.users.caddy.extraGroups = [ "nextcloud" ];

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

      php_fastcgi unix//run/phpfpm/nextcloud.sock {
        env front_controller_active true
      }

      file_server

      log {
        output file /var/log/caddy/access-nextcloud.log {
          mode 0640
        }
        format json
      }
    '';
  };
}
